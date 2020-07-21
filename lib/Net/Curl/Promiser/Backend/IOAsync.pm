package Net::Curl::Promiser::Backend::IOAsync;

use strict;
use warnings;

use parent 'Net::Curl::Promiser::Backend';

use IO::Async::Handle ();
use Net::Curl::Multi ();

use Net::Curl::Promiser::FDFHStore ();

sub new {
    my ($class, $loop) = @_;

    my $self = $class->SUPER::new();

    $self->{'_loop'} = $loop;
    $self->{'_fhstore'} = Net::Curl::Promiser::FDFHStore->new();

    return $self;
}

#----------------------------------------------------------------------

sub _CB_TIMER {
    my ($multi, $timeout_ms, $self) = @_;

    my $loop = $self->{'_loop'};

    if ( my $old_id = delete $self->{'timer_id'} ) {
        $loop->unwatch_time($old_id);
    }

    if ($timeout_ms != -1) {
        $self->{'timer_id'} = $loop->watch_time(
            after => $timeout_ms / 1000,
            code => sub { $self->time_out($multi) },
        );
    }

    return 1;
}

sub _get_handle {
    my ($self, $fd, $multi) = @_;

    return $self->{'_handle'}{$fd} ||= do {
        my $s = $self->{'_fhstore'}->get_fh($fd);

        my $handle = IO::Async::Handle->new(
            read_handle => $s,
            write_handle => $s,

            on_read_ready => sub {
                $self->process($multi, [$fd, Net::Curl::Multi::CURL_CSELECT_IN()]);
            },

            on_write_ready => sub {
                $self->process($multi, [$fd, Net::Curl::Multi::CURL_CSELECT_OUT()]);
            },
        );

        $self->{'_loop'}->add($handle);

        $handle;
    };
}

sub SET_POLL_IN {
    my ($self, $fd, $multi) = @_;

    my $h = $self->_get_handle($fd, $multi);

    $h->want_readready(1);
    $h->want_writeready(0);

    return;
}

sub SET_POLL_OUT {
    my ($self, $fd, $multi) = @_;

    my $h = $self->_get_handle($fd, $multi);

    $h->want_readready(0);
    $h->want_writeready(1);

    return;
}

sub SET_POLL_INOUT {
    my ($self, $fd, $multi) = @_;

    my $h = $self->_get_handle($fd, $multi);

    $h->want_readready(1);
    $h->want_writeready(1);

    return;
}

sub STOP_POLL {
    my ($self, $fd) = @_;

    if ( my $fh = delete $self->{'_handle'}{$fd} ) {
        $self->{'_loop'}->remove($fh);
    }
    else {
        #$self->_handle_extra_stop_poll($fd);
    }

    return;
}

1;
