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

my $test_count = 2 + $ClientTest::TEST_COUNT;

plan tests => $test_count;

SKIP: {
    eval { require Mojolicious; 1 } or skip "Mojolicious isn’t available: $@", $test_count;
    diag "Mojolicious version: $Mojolicious::VERSION";

    eval { require Mojo::IOLoop; 1 } or skip "Mojo::IOLoop isn’t available: $@", $test_count;
    eval { require Mojo::Promise; 1 } or skip "Mojo::Promise isn’t available: $@", $test_count;
    eval { my $p = Mojo::Promise->new( sub { } ); 1 } or skip "This Mojo::Promise isn’t ES6-compatible: $@", $test_count;

    require Net::Curl::Promiser::Mojo;

    local $SIG{'ALRM'} = 60;

    local $SIG{'CHLD'} = \&ClientTest::sigchld_handler;

    my $server = MyServer->new();

    my $port = $server->port();

    my $promiser = Net::Curl::Promiser::Mojo->new();

    can_ok( $promiser, 'add_handle_p' );

    my $promise = ClientTest::run($promiser, $port)->then( sub { print "big resolve\n" }, sub { $@ = shift; warn } );

    isa_ok( $promise, 'Mojo::Promise', 'promise object' );

    my $pr2 = $promise->finally( sub { Mojo::IOLoop->stop() } );

    Mojo::IOLoop->start();
}

done_testing();
