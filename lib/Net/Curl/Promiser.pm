package Net::Curl::Promiser;

use strict;
use warnings;

our $VERSION = '0.12';

=encoding utf-8

=head1 NAME

Net::Curl::Promiser - Asynchronous L<libcurl|https://curl.haxx.se/libcurl/>, the easy way!

=head1 DESCRIPTION

L<Net::Curl::Multi> is powerful but tricky to use: polling, callbacks,
timers, etc. This module does all of that for you and puts a Promise
interface on top of it, so asynchronous I/O becomes almost as simple as
synchronous I/O.

L<Net::Curl::Promiser> itself is a base class; you’ll need to provide
a subclass that works with whatever event interface you use.

This distribution provides the following usable subclasses:

=over

=item * L<Net::Curl::Promiser::Mojo> (for L<Mojolicious>)

=item * L<Net::Curl::Promiser::AnyEvent> (for L<AnyEvent>)

=item * L<Net::Curl::Promiser::IOAsync> (for L<IO::Async>)

=item * L<Net::Curl::Promiser::Select> (for manually-written
C<select()> loops)

=back

If the event interface you want to use isn’t compatible with one of the
above, you’ll need to create your own L<Net::Curl::Promiser> subclass.
This is undocumented but pretty simple; have a look at the ones above as
well as another based on Linux’s L<epoll(7)> in the distribution’s
F</examples>.

=head1 MEMORY LEAK DETECTION

This module will, by default, C<warn()> if its objects are C<DESTROY()>ed
during Perl’s global destruction phase. To suppress this behavior, set
C<$Net::Curl::Promiser::IGNORE_MEMORY_LEAKS> to a truthy value.

=head1 PROMISE IMPLEMENTATION

This class’s default Promise implementation is L<Promise::ES6>.
You can use a different one by overriding the C<PROMISE_CLASS()> method in
a subclass, as long as the substitute class’s C<new()> method works the
same way as Promise::ES6’s (which itself follows the ECMAScript standard).

(NB: L<Net::Curl::Promiser::Mojo> uses L<Mojo::Promise> instead of
Promise::ES6.)

=head2 B<Experimental> L<Promise::XS> support

Try out experimental Promise::XS support by running with
C<NET_CURL_PROMISER_PROMISE_ENGINE=Promise::XS> in your environment.
This will override C<PROMISE_CLASS()>.

=cut

#----------------------------------------------------------------------

use parent 'Net::Curl::Promiser::LeakDetector';

use Net::Curl::Multi ();

use constant _DEBUG => 0;

use constant _DEFAULT_TIMEOUT => 1000;

our $IGNORE_MEMORY_LEAKS;

#----------------------------------------------------------------------

=head1 GENERAL-USE METHODS

The following are of interest to any code that uses this module:

=head2 I<CLASS>->new(@ARGS)

Instantiates this class. This creates an underlying
L<Net::Curl::Multi> object and calls the subclass’s C<_INIT()>
method at the end, passing a reference to @ARGS.

(Most end classes of this module do not require @ARGS.)

=cut

sub new {
    my ($class, @args) = @_;

    my %props = (
        callbacks => {},
        to_fail => {},
        ignore_leaks => $IGNORE_MEMORY_LEAKS,
    );

    my $self = bless \%props, $class;

    my $multi = Net::Curl::Multi->new();
    $self->{'multi'} = $multi;

    my $backend = $self->_INIT(\@args);
    $self->{'backend'} = $backend;

    $multi->setopt(
        Net::Curl::Multi::CURLMOPT_TIMERDATA(),
        $backend,
    );

    $multi->setopt(
        Net::Curl::Multi::CURLMOPT_TIMERFUNCTION(),
        $backend->can('_CB_TIMER'),
    );

    $multi->setopt(
        Net::Curl::Multi::CURLMOPT_SOCKETDATA,
        $backend,
    );

    $multi->setopt(
        Net::Curl::Multi::CURLMOPT_SOCKETFUNCTION,
        \&_socket_fn,
    );

    return $self;
}

#----------------------------------------------------------------------

=head2 promise($EASY) = I<OBJ>->add_handle( $EASY )

A passthrough to the underlying L<Net::Curl::Multi> object’s
method of the same name, but the return is given as a Promise object.

That promise resolves with the passed-in $EASY object.
It rejects with either the error given to C<fail_handle()> or the
error that L<Net::Curl::Multi> object’s C<info_read()> returns.

B<IMPORTANT:> As with libcurl itself, HTTP-level failures
(e.g., 4xx and 5xx responses) are B<NOT> considered failures at this level.

=cut

sub add_handle {
    my ($self, $easy) = @_;

    return $self->{'backend'}->add_handle($easy, $self->{'multi'});
}

=head2 $obj = I<OBJ>->cancel_handle( $EASY )

Prematurely cancels $EASY. The associated promise will be abandoned
in pending state, never to resolve nor reject.

Returns I<OBJ>.

=cut

sub cancel_handle {
    my ($self, $easy) = @_;

    return $self->{'backend'}->cancel_handle($easy, $self->{'multi'});
}

=head2 $obj = I<OBJ>->fail_handle( $EASY, $REASON )

Like C<cancel_handle()> but rejects $EASY’s associated promise
with the given $REASON.

Returns I<OBJ>.

=cut

sub fail_handle {
    my ($self, $easy, $reason) = @_;

    return $self->{'backend'}->fail_handle($easy, $reason);
}

#----------------------------------------------------------------------

=head2 $obj = I<OBJ>->setopt( … )

A passthrough to the underlying L<Net::Curl::Multi> object’s
method of the same name. Returns I<OBJ> to facilitate chaining.

C<CURLMOPT_SOCKETFUNCTION> or C<CURLMOPT_SOCKETDATA> are set internally;
any attempt to set them via this interface will prompt an error.

=cut

sub setopt {
    my $self = shift;

    for my $opt ( qw( SOCKETFUNCTION  SOCKETDATA ) ) {
        my $fullopt = "CURLMOPT_$opt";

        if ($_[0] == Net::Curl::Multi->can($fullopt)->()) {
            my $ref = ref $self;
            die "Don’t set $fullopt via $ref!";
        }
    }

    $self->{'multi'}->setopt(@_);
    return $self;
}

=head2 $obj = I<OBJ>->handles( … )

A passthrough to the underlying L<Net::Curl::Multi> object’s
method of the same name.

=cut

sub handles {
   return shift()->{'multi'}->handles();
}

#----------------------------------------------------------------------

=head1 EVENT LOOP METHODS

The following are needed only when you’re managing an event loop directly:

=head2 $num = I<OBJ>->get_timeout()

Returns the underlying L<Net::Curl::Multi> object’s C<timeout()> value.

(NB: This value is in I<milliseconds>.)

This may not suit your needs; if you wish/need, you can handle timeouts
via the L<CURLMOPT_TIMERFUNCTION|Net::Curl::Multi/CURLMOPT_TIMERFUNCTION>
callback instead.

This should only be called (if it’s called at all) from event loop logic.

=cut

sub get_timeout {
    my ($self) = @_;

    return $self->{'multi'}->timeout();
}

#----------------------------------------------------------------------

=head2 $obj = I<OBJ>->process( @ARGS )

Tell the underlying L<Net::Curl::Multi> object which socket events have
happened.

If, in fact, no events have happened, then this calls
C<socket_action(CURL_SOCKET_TIMEOUT)> on the
L<Net::Curl::Multi> object (similar to C<time_out()>).

Finally, this reaps whatever pending HTTP responses may be ready and
resolves or rejects the corresponding Promise objects.

This should only be called from event loop logic.

Returns I<OBJ>.

=cut

sub process {
    my ($self, @fd_action_args) = @_;

    $self->{'backend'}->process( $self->{'multi'}, \@fd_action_args );

    return $self;
}

#----------------------------------------------------------------------

=head2 $is_active = I<OBJ>->time_out();

Tell the underlying L<Net::Curl::Multi> object that a timeout happened,
and reap whatever pending HTTP responses may be ready.

Calls C<socket_action(CURL_SOCKET_TIMEOUT)> on the
underlying L<Net::Curl::Multi> object. The return is the same as
that operation returns.

Since C<process()> can also do the work of this function, a call to this
function is just an optimization.

This should only be called from event loop logic.

=cut

sub time_out {
    my ($self) = @_;

    return $self->{'backend'}->time_out( $self->{'multi'} );
}

#----------------------------------------------------------------------

sub _socket_fn {
    my ( $multi, $fd, $action, $backend ) = @_[0, 2, 3, 5];

    # IMPORTANT: Removing handles within this function is likely to
    # corrupt libcurl.

    if ($action == Net::Curl::Multi::CURL_POLL_IN) {
        print STDERR "FD $fd, IN\n" if _DEBUG;

        $backend->SET_POLL_IN($fd, $multi);
    }
    elsif ($action == Net::Curl::Multi::CURL_POLL_OUT) {
        print STDERR "FD $fd, OUT\n" if _DEBUG;

        $backend->SET_POLL_OUT($fd, $multi);
    }
    elsif ($action == Net::Curl::Multi::CURL_POLL_INOUT) {
        print STDERR "FD $fd, INOUT\n" if _DEBUG;

        $backend->SET_POLL_INOUT($fd, $multi);
    }
    elsif ($action == Net::Curl::Multi::CURL_POLL_REMOVE) {
        print STDERR "FD $fd, STOP\n" if _DEBUG;

        $backend->STOP_POLL($fd, $multi);
    }
    else {
        warn( __PACKAGE__ . ": Unrecognized action $action on FD $fd\n" );
    }

    return 0;
}

#----------------------------------------------------------------------

=head1 EXAMPLES

See the distribution’s F</examples> directory.

=head1 SEE ALSO

If you use L<AnyEvent>, then L<AnyEvent::XSPromises> with
L<AnyEvent::YACurl> may be a nicer fit for you.

=head1 REPOSITORY

L<https://github.com/FGasper/p5-Net-Curl-Promiser>

=head1 LICENSE & COPYRIGHT

Copyright 2019-2020 Gasper Software Consulting.

This library is licensed under the same terms as Perl itself.

=cut

1;
