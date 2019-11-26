package ClientTest;

use strict;
use warnings;

use Test::More;

use Promise::ES6;

use Net::Curl::Easy qw(:constants);

use MyServer;

#use constant _paths => qw( foo bar biggie foo foo );
use constant _paths => qw( foo bar baz );

our $TEST_COUNT = 2 * _paths();

sub run {
    my ($promiser, $port) = @_;

    my @promises = map {
        my $path = $_;
        my $easy = Net::Curl::Easy->new();
        $easy->setopt( CURLOPT_URL() => "http://127.0.0.1:$port/$path" );

        # $easy->setopt( CURLOPT_VERBOSE() => 1 );

        $_ = q<> for @{$easy}{ qw(_head _body) };
        $easy->setopt( CURLOPT_HEADERDATA() => \$easy->{'_head'} );
        $easy->setopt( CURLOPT_FILE() => \$easy->{'_body'} );

        $promiser->add_handle($easy)->then( sub {
            my ($easy) = shift;

            is($easy->{'_head'}, $MyServer::HEAD, "headers: $path" );

            if ($path eq 'biggie') {
                is( $easy->{'_body'}, $MyServer::BIGGIE, "payload: $path" );
            }
            else {
                is( $easy->{'_body'}, "/$path", "payload: $path" );
            }
        }, sub { warn "REJECT $path: @_\n" } );
    } _paths();

    return Promise::ES6->all(\@promises);
}

1;
