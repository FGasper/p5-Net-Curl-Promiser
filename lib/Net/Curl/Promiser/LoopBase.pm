package Net::Curl::Promiser::LoopBase;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Net::Curl::Promiser::LoopBase - base class for event-loop-based implementations

=head1 INVALID METHODS

The following methods from L<Net::Curl::Promiser> are unneeded in instances
of this class and thus produce an exception if called:

=over

=item C<process()>

=item C<time_out()>

=item C<get_timeout()>

=back

=head1 TODO

This is a rather hacky way accomplish this. Refactor it to be more-better.

Also incorporate the copy-pasted timeout logic from subclasses.

=cut

#----------------------------------------------------------------------

use parent qw( Net::Curl::Promiser );

use Net::Curl ();

#----------------------------------------------------------------------

sub new {
    my $self = shift()->SUPER::new(@_);

    my ($backend, $multi) = @{$self}{'backend', 'multi'};

    $multi->setopt(
        Net::Curl::Multi::CURLMOPT_TIMERDATA(),
        $backend,
    );

    $multi->setopt(
        Net::Curl::Multi::CURLMOPT_TIMERFUNCTION(),
        $backend->can('_CB_TIMER'),
    );

    return $self;
}

sub _GET_FD_ACTION {
    return +{ @{ $_[1] } };
}

1;
