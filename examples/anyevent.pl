#!/usr/bin/env perl

use strict;
use warnings;

use Net::Curl::Easy qw(:constants);

use FindBin;

use lib "$FindBin::Bin/../lib";

use Net::Curl::Promiser::AnyEvent;

my @urls = (
    'http://perl.org',
    'http://perl.com',
    'http://metacpan.org',
);

#----------------------------------------------------------------------

my $promiser = Net::Curl::Promiser::AnyEvent->new();

my @promises;

for my $url (@urls) {
    my $handle = Net::Curl::Easy->new();
    $handle->setopt( CURLOPT_URL() => $url );
    $handle->setopt( CURLOPT_FOLLOWLOCATION() => 1 );

    push @promises, $promiser->add_handle($handle)->then(
        sub { print "$url completed.$/" },
        sub { warn "$url failed: " . shift },
    );
}

my $cv = AnyEvent->condvar();

Promise::ES6->all(\@promises)->finally($cv);

$cv->recv();
