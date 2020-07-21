package Net::Curl::Promiser::IOAsync;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Net::Curl::Promiser::IOAsync - support for L<IO::Async>

=head1 SYNOPSIS

    my $loop = IO::Async::Loop->new();

    my $promiser = Net::Curl::Promiser::IOAsync->new($loop);

    my $handle = Net::Curl::Easy->new();
    $handle->setopt( CURLOPT_URL() => $url );

    $promiser->add_handle($handle)->then(
        sub { print "$url completed.$/" },
        sub { warn "$url failed: " . shift },
    )->finally( sub { $loop->stop() } );

    $loop->run();

=head1 DESCRIPTION

This module provides an L<IO::Async>-compatible interface for
L<Net::Curl::Promiser>.

See F</examples> in the distribution for a fleshed-out demonstration.

B<NOTE:> The actual interface is that provided by
L<Net::Curl::Promiser::LoopBase>.

=cut

#----------------------------------------------------------------------

use parent 'Net::Curl::Promiser::LoopBase';

use Net::Curl::Promiser::Backend::IOAsync;

#----------------------------------------------------------------------

sub _INIT {
    my ($self, $args_ar) = @_;

    return Net::Curl::Promiser::Backend::IOAsync->new($args_ar->[0]);
}

1;
