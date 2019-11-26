package Net::Curl::Promiser::Mojo;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Net::Curl::Promiser::Mojo - support for L<Mojolicious>

=head1 SYNOPSIS

    my $promiser = Net::Curl::Promiser::Mojo->new();

    my $handle = Net::Curl::Easy->new();
    $handle->setopt( CURLOPT_URL() => $url );

    $promiser->add_handle($handle)->then(
        sub { print "$url completed.$/" },
        sub { warn "$url failed: " . shift },
    )->finally( sub { Mojo::IOLoop->stop() } );

    Mojo::IOLoop->start()();

=head1 DESCRIPTION

This module provides an L<AnyEvent>-compatible interface for
L<Net::Curl::Promiser>.

See F</examples> in the distribution for a fleshed-out demonstration.

B<NOTE:> The actual interface is that provided by
L<Net::Curl::Promiser::LoopBase>.

=head1 STATUS

B<EXPERIMENTAL:> This module doesn’t pass its own tests on all platforms.
(On MacOS it nearly always fails.)

=cut

#----------------------------------------------------------------------

use parent 'Net::Curl::Promiser::LoopBase';

use Net::Curl::Multi ();

use Mojo::IOLoop;

#----------------------------------------------------------------------

sub _INIT {
    my ($self, $args_ar) = @_;

    $self->setopt( Net::Curl::Multi::CURLMOPT_TIMERFUNCTION(), \&_cb_timer );
    $self->setopt( Net::Curl::Multi::CURLMOPT_TIMERDATA(), $self );

    return;
}

sub _cb_timer {
    my ($multi, $timeout_ms, $self) = @_;

    for my $id ( delete @{$self}{'onetimer','recurtimer'} ) {
        next if !$id;
        Mojo::IOLoop->remove($id);
    }

    if ($timeout_ms < 0) {
        if ($multi->handles()) {
            my $cb = sub {
                $self->_time_out_in_loop();
            };

            $self->{'onetimer'} = Mojo::IOLoop->timer( 5 => $cb );
            $self->{'recurtimer'} = Mojo::IOLoop->recurring( 5 => $cb );
        }
    }
    else {
        $self->{onetimer} = Mojo::IOLoop->timer(
            $timeout_ms / 1000,
            sub {
                $self->_time_out_in_loop();
            },
        );
    }

    return 1;
}

sub _io {
    my ($self, $fd, $read_yn, $write_yn) = @_;

    my $socket = $self->{'_watched_sockets'}{$fd} ||= do {
        open my $s, '+>>&=' . $fd or die "fd->fh failed: $!";

        Mojo::IOLoop->singleton->reactor->io(
            $s,
            sub {
                $self->_process_in_loop($fd, $_[1] ? Net::Curl::Multi::CURL_CSELECT_OUT() : Net::Curl::Multi::CURL_CSELECT_IN());
            },
        );

        $s;
    };

    Mojo::IOLoop->singleton->reactor->watch(
        $socket,
        $read_yn,
        $write_yn,
    );

    return;
}

sub _SET_POLL_IN {
    my ($self, $fd) = @_;

    $self->_io( $fd, 1, 0 );

    return;
}

sub _SET_POLL_OUT {
    my ($self, $fd) = @_;

    $self->_io( $fd, 0, 1 );

    return;
}

sub _SET_POLL_INOUT {
    my ($self, $fd) = @_;

    $self->_io( $fd, 1, 1 );

    return;
}

sub _STOP_POLL {
    my ($self, $fd) = @_;

    if (my $socket = delete $self->{'_watched_sockets'}{$fd}) {
        Mojo::IOLoop->remove($socket);
    }
    else {
        warn "Mojo “extra” stop: [$fd]";
    }

    return;
}

1;
