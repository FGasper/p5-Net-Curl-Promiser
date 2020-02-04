package Net::Curl::Promiser::AnyEvent;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Net::Curl::Promiser::AnyEvent - support for L<AnyEvent>

=head1 SYNOPSIS

    my $promiser = Net::Curl::Promiser::AnyEvent->new();

    my $handle = Net::Curl::Easy->new();
    $handle->setopt( CURLOPT_URL() => $url );

    my $cv = AnyEvent->condvar();

    $promiser->add_handle($handle)->then(
        sub { print "$url completed.$/" },
        sub { warn "$url failed: " . shift },
    )->finally($cv);

    $cv->recv();

=head1 DESCRIPTION

This module provides an L<AnyEvent>-compatible interface for
L<Net::Curl::Promiser>.

See F</examples> in the distribution for a fleshed-out demonstration.

B<NOTE:> The actual interface is that provided by
L<Net::Curl::Promiser::LoopBase>.

=cut

#----------------------------------------------------------------------

use parent 'Net::Curl::Promiser::LoopBase';

use Net::Curl::Multi ();

use AnyEvent;

#----------------------------------------------------------------------

sub _INIT {
    my ($self, $args_ar) = @_;

    $self->{'_watches'} = {};

    $self->setopt( Net::Curl::Multi::CURLMOPT_TIMERFUNCTION(), \&_cb_timer );
    $self->setopt( Net::Curl::Multi::CURLMOPT_TIMERDATA(), $self );

    return;
}

sub _cb_timer {
    my ($multi, $timeout_ms, $self) = @_;

    my $watches_hr = ($self->{'_watches'} ||= {});

    my $cb = sub {
        #$self->_time_out_in_loop();
        #$multi->socket_action( Net::Curl::Multi::CURL_SOCKET_TIMEOUT() );
print STDERR "N::C::P::AE - before timeout ($timeout_ms)\n";
        $self->{'multi'}->socket_action( Net::Curl::Multi::CURL_SOCKET_TIMEOUT() );
print STDERR "N::C::P::AE - after timeout ($timeout_ms)\n";

use Data::Dumper;
print STDERR Dumper( $watches_hr );

        # $self->_process_pending();

        return;
    };

    delete $self->{'timer'};

    if ($timeout_ms < 0) {
        if ($multi->handles()) {
            $self->{'timer'} = AnyEvent->timer(
                after => 5,
                interval => 5,
                cb => $cb,
            );
        }
    }
    elsif ($timeout_ms) {
        $self->{timer} = AnyEvent->timer(
            after => $timeout_ms / 1000,
            cb => $cb,
        );
    }
    else {
        &AnyEvent::postpone($cb);
    }

    return 1;
}

sub _io {
    my ($self, $fd, $direction, $action_num) = @_;

    print STDERR "N::C::P - FD $fd poll $direction$/" if $self->_DEBUG;
    print STDERR AnyEvent->now() . $/;

    $self->{'_watches'}{$fd}{$direction} = AnyEvent->io(
        fh => $fd,
        poll => $direction,
        cb => sub {
            print STDERR "N::C::P - FD $fd event $direction$/" if $self->_DEBUG;
            $self->_process_in_loop($fd, $action_num);
        },
    );

    return;
}

sub _SET_POLL_IN {
    my ($self, $fd) = @_;

    $self->_io( $fd, 'r', Net::Curl::Multi::CURL_CSELECT_IN() );

    delete $self->{'_watches'}{$fd}{'w'};

    return;
}

sub _SET_POLL_OUT {
    my ($self, $fd) = @_;

    $self->_io( $fd, 'w', Net::Curl::Multi::CURL_CSELECT_OUT() );

    delete $self->{'_watches'}{$fd}{'r'};

    return;
}

sub _SET_POLL_INOUT {
    my ($self, $fd) = @_;

    $self->_io( $fd, 'r', Net::Curl::Multi::CURL_CSELECT_IN() );
    $self->_io( $fd, 'w', Net::Curl::Multi::CURL_CSELECT_OUT() );

    return;
}

sub _STOP_POLL {
    my ($self, $fd) = @_;

    print STDERR "N::C::P - FD $fd stop$/" if $self->_DEBUG;
    print STDERR AnyEvent->now() . $/;

    delete $self->{'_watches'}{$fd};

    return;
}

1;
