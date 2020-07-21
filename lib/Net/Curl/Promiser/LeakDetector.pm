package Net::Curl::Promiser::LeakDetector;

use strict;
use warnings;

sub DESTROY {
    my ($self) = @_;

    if (!$self->{'ignore_leaks'} && ${^GLOBAL_PHASE} && ${^GLOBAL_PHASE} eq 'DESTRUCT' ) {
use Data::Dumper;
$Data::Dumper::Deparse = 1;
print STDERR Dumper $self;
        warn "$self: destroyed at global destruction; memory leak likely!";
    }
}

1;
