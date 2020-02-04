#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
# use Test::FailWarnings;

use Net::Curl::Easy;

use FindBin;
use lib "$FindBin::Bin/lib";

use MyServer;
use ClientTest;

plan tests => $ClientTest::TEST_COUNT;

$ENV{PERL_ANYEVENT_VERBOSE} = 8;

SKIP: {
    eval { require AnyEvent; 1 } or skip "AnyEvent isn’t available: $@", $ClientTest::TEST_COUNT;

    require Net::Curl::Promiser::AnyEvent;

    local $SIG{'ALRM'} = 60;

    # local $SIG{'CHLD'} = \&ClientTest::sigchld_handler;

    my $server = MyServer->new();

    my $port = $server->port();

    my $promiser = Net::Curl::Promiser::AnyEvent->new();

    my $cv = AnyEvent->condvar();

    my $p = ClientTest::run($promiser, $port)->finally($cv);

    $cv->recv();

    diag "Finished event loop: $0";

    $server->finish();
}

done_testing();
