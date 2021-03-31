package t::cancel;

use strict;
use warnings;
use autodie;

use Test::More;
use Test::Deep;
use Test::FailWarnings;

use Net::Curl::Easy qw(:constants);

use Net::Curl::Promiser::Select;

use Socket;

sub _create_server_socket {
    socket my $srv, Socket::AF_INET, Socket::SOCK_STREAM, 0;
    bind $srv, Socket::pack_sockaddr_in(0, "\x7f\0\0\1");
    listen $srv, 10;

    my ($server_port) = Socket::unpack_sockaddr_in( getsockname($srv) );

    return ($srv, $server_port);
}

{
    my $promiser = Net::Curl::Promiser::Select->new();

    my @list;

    my ($srv, $server_port) = _create_server_socket();
    my $easy = _make_req($server_port);

    $promiser->add_handle($easy)->then(
        sub {
            diag explain [ res => @_ ];
            push @list, [ res => @_ ];
        },
        sub {
            diag explain [ rej => @_ ];
            push @list, [ rej => @_ ];
        },
    );

    my ($r, $w, $e) = $promiser->get_vecs();

    $promiser->process( $r, $w );

    ($r, $w, $e) = $promiser->get_vecs();

    grep { tr<\0><>c } ($r, $w, $e) or do {
        warn 'There needs to be *some* polling … ?';
    };

    $promiser->cancel_handle($easy);

    ($r, $w, $e) = $promiser->get_vecs();

    cmp_deeply(
        [$r, $w, $e],
        array_each( none( re( qr<[^\0]> ) ) ),
        'no vecs are non-NUL',
    );

    is_deeply( \@list, [], 'promise remains pending' ) or diag explain \@list;
}

for my $fail_ar ( [0], ['haha'] ) {
    my $promiser = Net::Curl::Promiser::Select->new();

    # diag "fail: " . (explain $fail_ar)[0];

    my @list;

    my ($srv, $server_port) = _create_server_socket();
    my $easy = _make_req($server_port);

    $promiser->add_handle($easy)->then(
        sub {
            diag explain [ res => @_ ];
            push @list, [ res => @_ ];
        },
        sub {
            diag explain [ rej => @_ ];
            push @list, [ rej => @_ ];
        },
    );

    my ($r, $w, $e) = $promiser->get_vecs();

    $promiser->process( $r, $w );

    ($r, $w, $e) = $promiser->get_vecs();

    grep { tr<\0><>c } ($r, $w, $e) or do {
        warn 'There needs to be *some* polling … ?';
    };

    $promiser->fail_handle($easy, @$fail_ar);

    ($r, $w, $e) = $promiser->get_vecs();

    cmp_deeply(
        [$r, $w, $e],
        array_each( none( re( qr<[^\0]> ) ) ),
        'no vecs are non-NUL',
    );

    is_deeply(
        \@list,
        [ [ rej => $fail_ar->[0] ] ],
        'promise rejected',
    ) or diag explain \@list;
}

#----------------------------------------------------------------------

sub _make_req {
    my $port = shift;

    my $easy = Net::Curl::Easy->new();
    $easy->setopt( CURLOPT_URL() => "http://127.0.0.1:$port" );

    $_ = q<> for @{$easy}{ qw(_head _body) };
    $easy->setopt( CURLOPT_HEADERDATA() => \$easy->{'_head'} );
    $easy->setopt( CURLOPT_FILE() => \$easy->{'_body'} );
    $easy->setopt( CURLOPT_VERBOSE() => 1 );

    return $easy;
}

done_testing;
