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

Also incorporate the copy-pasted timeout logic from AnyEvent and IO::Async
implementations.

=cut

#----------------------------------------------------------------------

use parent qw( Net::Curl::Promiser );

*_process_in_loop = __PACKAGE__->can('SUPER::process');
*_time_out_in_loop = __PACKAGE__->can('SUPER::process');

sub process { die 'Unneeded method: ' . (caller 0)[3] };
sub get_timeout { die 'Unneeded method: ' . (caller 0)[3] };
sub time_out { die 'Unneeded method: ' . (caller 0)[3] };

sub _GET_FD_ACTION {
    my ($self, $args_ar) = @_;

    return +{ @$args_ar };
}

1;
