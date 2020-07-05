#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use Net::Curl::Easy;

use FindBin;
use lib "$FindBin::Bin/lib";

use MyServer;
use ClientTest;

plan tests => 1 + $ClientTest::TEST_COUNT;

SKIP: {
    eval { require AnyEvent::Loop; 1 } or skip "AnyEvent isn’t available: $@", $ClientTest::TEST_COUNT;

    diag "Using AnyEvent $AnyEvent::VERSION; backend: " . AnyEvent::detect();

    require Net::Curl::Promiser::AnyEvent;

    my $server = MyServer->new();

    my $port = $server->port();

    my $promiser = Net::Curl::Promiser::AnyEvent->new();

    my $cv = AnyEvent->condvar();

    ClientTest::run($promiser, $port)->finally($cv);

    $cv->recv();

    #----------------------------------------------------------------------

    _test_cancel($promiser, $port);

    #----------------------------------------------------------------------

diag "finishing";
    $server->finish();
}

#----------------------------------------------------------------------

sub _test_cancel {
    my ($promiser, $port) = @_;
diag "one";

    require Net::Curl::Easy;
    my $easy = Net::Curl::Easy->new();
    $easy->setopt( Net::Curl::Easy::CURLOPT_URL() => "http://127.0.0.1:$port/foo" );

    # $easy->setopt( CURLOPT_VERBOSE() => 1 );

    # Even on the slowest machines this ought to do it.
    $easy->setopt( Net::Curl::Easy::CURLOPT_TIMEOUT() => 30 );

    my $fate;

    $promiser->add_handle($easy)->then(
        sub { $fate = [0, shift] },
        sub { $fate = [1, shift] },
    );

    my @watches;

    my $cv = AnyEvent->condvar();

    $promiser->cancel_handle($easy);

    push @watches, AnyEvent->timer(
        after => 1,
        cb => sub {
            $cv->();
        },
    );

    $cv->recv();

    is( $fate, undef, 'canceled promise remains pending' ) or diag explain $fate;
diag "finish test_cancel";
}
