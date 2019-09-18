package Net::Curl::Promiser::Select;

use strict;
use warnings;

use parent 'Net::Curl::Promiser';

use Net::Curl::Multi ();

use Data::FDSet ();

sub new {
    my ($class) = @_;

    my $self = $class->SUPER::new();

    $_ = q<> for @{$self}{ qw( rin win ein ) };

    $_ = {} for @{$self}{ qw( rfds wfds fds ) };

    return $self;
}

sub get_vecs {
    my ($self) = @_;

    return @{$self}{'rin', 'win', 'ein'};
}

sub _GET_FD_ACTION {
    my ($self, $args_ar) = @_;

    my %fd_action;

    $fd_action{$_} = Net::Curl::Multi::CURL_CSELECT_IN() for @{ Data::FDSet::get_fds(\$args_ar->[0]) };
    $fd_action{$_} += Net::Curl::Multi::CURL_CSELECT_OUT() for @{ Data::FDSet::get_fds(\$args_ar->[1]) };

    return \%fd_action;
}

#sub get_read_fds {
#    my ($self) = @_;
#    return keys %{ $self->{'rfds'} };
#}
#
#sub get_write_fds {
#    my ($self) = @_;
#    return keys %{ $self->{'wfds'} };
#}
#
#sub get_all_fds {
#    my ($self) = @_;
#    return keys %{ $self->{'fds'} };
#}

sub _SET_POLL_IN {
    my ($self, $fd) = @_;
    $self->{'rfds'}{$fd} = $self->{'fds'}{$fd} = delete $self->{'wfds'}{$fd};

    vec( $self->{'rin'}, $fd, 1 ) = 1;
    vec( $self->{'win'}, $fd, 1 ) = 0;
    vec( $self->{'ein'}, $fd, 1 ) = 1;

    return;
}

sub _SET_POLL_OUT {
    my ($self, $fd) = @_;
    $self->{'wfds'}{$fd} = $self->{'fds'}{$fd} = delete $self->{'rfds'}{$fd};

    vec( $self->{'rin'}, $fd, 1 ) = 0;
    vec( $self->{'win'}, $fd, 1 ) = 1;
    vec( $self->{'ein'}, $fd, 1 ) = 1;

    return;
}

sub _SET_POLL_INOUT {
    my ($self, $fd) = @_;
    $self->{'rfds'}{$fd} = $self->{'wfds'}{$fd} = $self->{'fds'}{$fd} = undef;

    vec( $self->{'rin'}, $fd, 1 ) = 1;
    vec( $self->{'win'}, $fd, 1 ) = 1;
    vec( $self->{'ein'}, $fd, 1 ) = 1;

    return;
}

sub _STOP_POLL {
    my ($self, $fd) = @_;
    delete $self->{'rfds'}{$fd};
    delete $self->{'wfds'}{$fd};
    delete $self->{'fds'}{$fd};

    vec( $self->{'rin'}, $fd, 1 ) = 0;
    vec( $self->{'win'}, $fd, 1 ) = 0;
    vec( $self->{'ein'}, $fd, 1 ) = 0;

    return;
}

1;
