package Net::Curl::Promiser::Select;

use parent 'Net::Curl::Promiser';

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

sub get_read_fds {
    my ($self) = @_;
    return keys %{ $self->{'rfds'} };
}

sub get_write_fds {
    my ($self) = @_;
    return keys %{ $self->{'wfds'} };
}

sub get_all_fds {
    my ($self) = @_;
    return keys %{ $self->{'fds'} };
}

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

__END__

#----------------------------------------------------------------------
package Cpanel::HTTP::AsyncClient::Epoll;

use parent -norequire => 'Cpanel::HTTP::AsyncClient';

use Cpanel::Epoll ();

my $EPOLLINOUT = $Cpanel::Epoll::EPOLLIN | $Cpanel::Epoll::EPOLLOUT;

sub new($class, $epoll) {
    my $self = $class->SUPER::new();

    $self->{'_epoll'} = $epoll;

    return $self;
}

sub _set_epoll($self, $fd, $evts_mask) {
    if ( exists $self->{'_fds'}{$fd} ) {
        $self->{'_epoll'}->modify( $fd, $evts_mask );
    }
    else {
        $self->{'_epoll'}->add( $fd, $evts_mask );
        $self->{'_fds'}{$fd} = undef;
    }

    return;
}

sub _SET_POLL_IN($self, $fd) {
    return $self->_set_epoll( $fd, $Cpanel::Epoll::EPOLLIN );
}

sub _SET_POLL_OUT($self, $fd) {
    return $self->_set_epoll( $fd, $Cpanel::Epoll::EPOLLOUT );
}

sub _SET_POLL_INOUT($self, $fd) {
    return $self->_set_epoll( $fd, $EPOLLINOUT );
}

sub _STOP_POLL($self, $fd) {
    if ( delete $self->{'_fds'}{$fd} ) {
        $self->{'_epoll'}->delete( $fd );
    }

    return;
}

1;
