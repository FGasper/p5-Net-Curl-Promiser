package Net::Curl::Promiser::Select;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

Net::Curl::Promiser::Select

=head1 DESCRIPTION

This module implements L<Net::Curl::Promiser> via Perl’s
L<select()|perlfunc/select> built-in.

See F</examples> in the distribution for a fleshed-out demonstration.

This is “the hard way” to do this, by the way. Your life will be simpler
if you use (or create) an event-loop-based implementation like
L<Net::Curl::Promiser::AnyEvent> or L<Net::Curl::Promiser::IOAsync>.
See F</examples> for comparisons.

=cut

#----------------------------------------------------------------------

use parent 'Net::Curl::Promiser';

use Net::Curl::Promiser::Backend::Select;

#----------------------------------------------------------------------

=head1 C<process( $READ_MASK, $WRITE_MASK )>

Instances of this class should pass the read and write bitmasks
to the C<process()> method that otherwise would be passed to Perl’s
C<select()> built-in.

=head1 METHODS

The following are added in addition to the base class methods:

=head2 ($rmask, $wmask, $emask) = I<OBJ>->get_vecs();

Returns the bitmasks to use as input to C<select()>.

Note that, since these are copies of I<OBJ>’s internal values, you don’t
need to copy them again before calling C<select()>.

=cut

sub get_vecs {
    return shift()->{'backend'}->get_vecs();
}

#----------------------------------------------------------------------

=head2 @fds = I<OBJ>->get_fds();

Returns the file descriptors that I<OBJ> tracks—or, in scalar context, the
count of such. Useful to check for exception events.

=cut

sub get_fds {
    return shift()->{'backend'}->get_fds();
}

#----------------------------------------------------------------------

=head2 @fds = I<OBJ>->get_timeout();

Translates the base class’s implementation of this method to seconds
(since that’s what C<select()> expects).

=cut

sub get_timeout {
    my $timeout = $_[0]->SUPER::get_timeout();

    return( ($timeout == -1) ? $timeout : $timeout / 1000 );
}

#----------------------------------------------------------------------

sub _INIT {
    return Net::Curl::Promiser::Backend::Select->new();
}





1;
