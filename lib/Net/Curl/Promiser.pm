package Net::Curl::Promiser;

use strict;
use warnings;

use Promise::ES6 ();

use Net::Curl::Multi ();

use constant _DEFAULT_TIMEOUT => 1000;

sub new {
    my ($class) = @_;

    my %props = (
        callbacks => {},
        to_fail => {},
    );

    my $self = bless \%props, $class;

    my $curl = Net::Curl::Multi->new();
    $self->{'curl'} = $curl;

    $curl->setopt(
        Net::Curl::Multi::CURLMOPT_SOCKETDATA,
        $self,
    );

    $curl->setopt(
        Net::Curl::Multi::CURLMOPT_SOCKETFUNCTION,
        \&_socket_fn,
    );

    if (my $timer_fn = $class->can('_ON_TIMEOUT_CHANGE')) {
        $curl->setopt(
            Net::Curl::Multi::CURLMOPT_TIMERDATA,
            $self,
        );

        $curl->setopt(
            Net::Curl::Multi::CURLMOPT_TIMERFUNCTION,
            $timer_fn,
        );
    }

    return $self;
}

sub time_out {
    my ($self) = @_;

    my $is_active = $self->{'curl'}->socket_action( Net::Curl::Multi::CURL_SOCKET_TIMEOUT() );

    $self->_process_pending();

    return $is_active;
}

sub process {
    my ($self, $send_fds_ar, $receive_fds_ar) = @_;

    for my $fd (@$send_fds_ar) {
        $self->{'curl'}->socket_action( $fd, Net::Curl::Multi::CURL_CSELECT_OUT() );
    }

    for my $fd (@$receive_fds_ar) {
        $self->{'curl'}->socket_action( $fd, Net::Curl::Multi::CURL_CSELECT_IN() );
    }

    $self->_process_pending();

    return $self;
}

sub handles {
   return shift()->{'curl'}->handles();
}

sub get_timeout {
    my ($self) = @_;

    my $timeout = $self->{'curl'}->timeout();

    return( $timeout < 0 ? _DEFAULT_TIMEOUT() : $timeout );
}

sub add_handle {
    my ($self, $easy) = @_;

   $self->{'curl'}->add_handle($easy);

   my $promise = Promise::ES6->new( sub {
       $self->{'callbacks'}{$easy} = \@_;
   } );

   return $promise;
}

sub fail_handle {
    my ($self, $easy, $reason) = @_;

    $self->{'to_fail'}{$easy} = [ $easy, $reason ];

    return;
}

#----------------------------------------------------------------------

sub _socket_fn {
    my ( $multi, $easy, $fd, $action, $assign, $self ) = @_;

    if ($action == Net::Curl::Multi::CURL_POLL_IN) {
        $self->_SET_POLL_IN($fd);
    }
    elsif ($action == Net::Curl::Multi::CURL_POLL_OUT) {
        $self->_SET_POLL_OUT($fd);
    }
    elsif ($action == Net::Curl::Multi::CURL_POLL_INOUT) {
        $self->_SET_POLL_INOUT($fd);
    }
    elsif ($action == Net::Curl::Multi::CURL_POLL_REMOVE) {
        $self->_STOP_POLL($fd);
    }

    return 0;
}

sub _socket_action {
    my ($self, $fd, $direction) = @_;

    my $is_active = $self->{'curl'}->socket_action( $fd, $direction );

    $self->_process_pending();

    return $is_active;
}

sub _finish_handle {
    my ($self, $easy, $cb_idx, $payload) = @_;

    delete $self->{'to_fail'}{$easy};

    $self->{'curl'}->remove_handle( $easy );

    if ( my $cb_ar = delete $self->{'callbacks'}{$easy} ) {
        $cb_ar->[$cb_idx]->($payload);
    }

    return;
}

sub _clear_failed {
    my ($self) = @_;

    for my $easy_str ( keys %{ $self->{'to_fail'} } ) {
        my $val_ar = delete $self->{'to_fail'}{$easy_str};
        my ($easy, $reason) = @$val_ar;
        $self->_finish_handle( $easy, 1, $reason );
    }

    return;
}

sub _process_pending {
    my ($self) = @_;

    while ( my ( $msg, $easy, $result ) = $self->{'curl'}->info_read() ) {

        if ($msg != Net::Curl::Multi::CURLMSG_DONE()) {
            die "Unrecognized info_read() message: [$msg]";
        }

        if ( my $val_ar = delete $self->{'to_fail'}{$easy} ) {
            my ($easy, $reason) = @$val_ar;
            $self->_finish_handle( $easy, 1, $reason );
        }
        else {
            $self->_finish_handle(
                $easy,
                ($result == 0) ? ( 0 => $easy ) : ( 1 => $result ),
            );
        }
    }

    $self->_clear_failed();

    return;
}

1;
