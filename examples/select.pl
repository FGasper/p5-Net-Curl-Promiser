#!/usr/bin/env perl

use strict;
use warnings;

use Net::Curl::Easy qw(:constants);

use FindBin;

use lib "$FindBin::Bin/../lib";

use Net::Curl::Promiser::Select;

my @urls = (
    'http://perl.com',
    'http://metacpan.org',
);

#----------------------------------------------------------------------

my $http = Net::Curl::Promiser::Select->new();

for my $url (@urls) {
    my $handle = Net::Curl::Easy->new();
    $handle->setopt( CURLOPT_URL() => $url );
    $handle->setopt( CURLOPT_FOLLOWLOCATION() => 1 );
    $http->add_handle($handle)->then(
        sub { print "$url completed.\." },
        sub { warn "$url: " . shift },
    );
}

#----------------------------------------------------------------------

use Data::FDSet;

$_ = Data::FDSet->new() for my ($rout, $wout, $eout);

while ($http->handles()) {
    ($$rout, $$wout) = $http->get_vecs();
    my $timeout = $http->get_timeout() / 1000;

    my $got = select $$rout, $$wout, $$eout, $timeout;

    if ($got == 0) {
        $http->time_out();
    }
    elsif ($got > 0) {
        for my $fd ( $http->get_all_fds() ) {
            warn "problem (?) on FD $fd!" if $eout->has($fd);
        }

        my @rdrs = $http->get_read_fds();
        my @wtrs = $http->get_write_fds();

        $http->process( \@wtrs, \@rdrs );
    }
    else {
        die "select(): $!";
    }
}
