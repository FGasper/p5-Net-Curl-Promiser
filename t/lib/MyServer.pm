package MyServer;

use strict;
use warnings;
use autodie;

use Test::More;

use Time::HiRes;
use Socket;

our $CRLF = "\x0d\x0a";
our $HEAD_START = join(
    $CRLF,
    'HTTP/1.0 200 OK',
    'X-test: Yay',
    'Content-type: text/plain',
    q<>
);

our $BIGGIE = ('x' x 512);

sub new {
    my ($class) = @_;

    my $srv = _create_socket();

    my ($port) = Socket::unpack_sockaddr_in(getsockname $srv);

    diag "SERVER PORT: [$port] ($0)";

    my $pid = fork or do {
        my $ok = eval {
            CustomServer::HTTP::run($srv);
            1;
        };

        warn if !$ok;
        exit( $ok ? 0 : 1 );
    };

    diag "server pid: $pid ($0)";

    close $srv;

    return bless [$pid, $port], $class;
}

sub _create_socket {
    socket my $srv, Socket::AF_INET, Socket::SOCK_STREAM, 0;

    bind $srv, Socket::pack_sockaddr_in(0, "\x7f\0\0\1");

    listen $srv, 10;

    return $srv;
}

sub port { $_[0][1] }

sub DESTROY {
    my ($self ) = @_;

    local $SIG{'CHLD'};

    my $pid = $self->[0];

    my $SIG = 'QUIT';

    diag "Destroying server (PID $pid) via SIG$SIG …";

    my $reaped;

    while ( 1 ) {
        if (1 == waitpid $pid, 1) {
            diag "Reaped";

            $reaped = 1;
            last;
        }

        CORE::kill($SIG, $pid) or do {
            warn "kill($SIG, $pid): $!" if !$!{'ESRCH'};
            last;
        };

        Time::HiRes::sleep(0.1);
    }

    if (!$reaped) {
        diag "Done sending SIG$SIG; waiting …";

        waitpid $pid, 0;
    }

    diag "Finished waiting.";

    return;
}

#----------------------------------------------------------------------
package CustomServer::HTTP;

use autodie;

use Test::More;

# A blocking, non-forking server.
# Written this way to achieve maximum simplicity.
sub run {
    my ($socket) = @_;

    while (1) {
        accept( my $cln, $socket );

        diag "PID $$ received connection";

        my $buf = q<>;
        while (-1 == index($buf, "\x0d\x0a\x0d\x0a")) {
            sysread( $cln, $buf, 512, length $buf );
        }

        diag "PID $$ received headers";

        $buf =~ m<GET \s+ (\S+)>x or die "Bad request: $buf";
        my $uri_path = $1;

        syswrite $cln, $MyServer::HEAD_START;
        syswrite $cln, "X-URI: $uri_path$MyServer::CRLF";
        syswrite $cln, $MyServer::CRLF;

        syswrite $cln, ( $uri_path eq '/biggie' ? $MyServer::BIGGIE : $uri_path );
        diag "PID $$ wrote response";

    }
}
