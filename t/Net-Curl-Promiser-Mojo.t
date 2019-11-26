#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

#use lib "/Users/felipe/code/perl-Net-Curl/lib";
#use lib "/Users/felipe/code/perl-Net-Curl/blib";
#use lib "/Users/felipe/code/perl-Net-Curl/blib/arch";
use Net::Curl::Easy;

#print "$_$/" for sort values %INC;
#exit;

use FindBin;
use lib "$FindBin::Bin/lib";

use MyServer;
use ClientTest;

plan tests => $ClientTest::TEST_COUNT;

SKIP: {
    eval { require Mojo::IOLoop; 1 } or skip "Mojo::IOLoop isn’t available: $@", $ClientTest::TEST_COUNT;

    require Net::Curl::Promiser::Mojo;

    local $SIG{'ALRM'} = 60;

    local $SIG{'CHLD'} = sub {
        my $pid = waitpid -1, 1;
        die "Subprocess $pid ended prematurely!";
    };

    my $server = MyServer->new();

    my $port = $server->port();

    my $promiser = Net::Curl::Promiser::Mojo->new();

    my $promise = ClientTest::run($promiser, $port)->catch( sub { $@ = shift; warn } );

    $promise->finally( sub { Mojo::IOLoop->stop() } );

    Mojo::IOLoop->start();
}

done_testing();
