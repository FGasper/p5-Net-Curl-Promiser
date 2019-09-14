#!/usr/bin/env perl

package main;

use strict;
use warnings;

use Linux::Perl::epoll ();

my @urls = (
    'http://perl.com',
    'http://metacpan.org',
);

my $epoll = Linux::Perl::epoll->new();

#----------------------------------------------------------------------

my $http = My::Curl::Epoll->new($epoll);

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

while ($http->handles()) {
    my @events = $epl->wait(
        maxevents => 10,
        timeout => $http->get_timeout() / 1000,
    );

    my (@rcv, @snd);

    while ( my ($fd, $evts_num) = splice @events, 0, 2 ) {
        if ($evts_num & $http->EVENT_NUMBER()->{'IN'}) {
            push @rcv, $fd;
        }

        if ($evts_num & $http->EVENT_NUMBER()->{'OUT'}) {
            push @snd, $fd;
        }
    }

    $http->process( \@snd, \@rcv );
}

#----------------------------------------------------------------------

package My::Curl::Epoll;

sub new {
    my ($class, $epoll) = @_;

    my $self = $class->SUPER::new();

    $self->{'_epoll'} = $epoll;

    return $self;
}

sub _set_epoll {
    my ($self, $fd, @events) = @_;

    if ( exists $self->{'_fds'}{$fd} ) {
        $self->{'_epoll'}->modify( $fd, events => \@events );
    }
    else {
        $self->{'_epoll'}->add( $fd, events => \@events );
        $self->{'_fds'}{$fd} = undef;
    }

    return;
}

sub _SET_POLL_IN {
    my ($self, $fd) = @_;

    return $self->_set_epoll( $fd, 'IN' );
}

sub _SET_POLL_OUT {
    my ($self, $fd) = @_;
    return $self->_set_epoll( $fd, 'OUT' );
}

sub _SET_POLL_INOUT {
    my ($self, $fd) = @_;
    return $self->_set_epoll( $fd, 'IN', 'OUT' );
}

sub _STOP_POLL {
    my ($self, $fd) = @_;
    if ( delete $self->{'_fds'}{$fd} ) {
        $self->{'_epoll'}->delete( $fd );
    }

    return;
}

1;
