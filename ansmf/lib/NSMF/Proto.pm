package NSMF::Proto;

use strict;
use v5.10;

use POE;
use NSMF::Util;

my $instance;

sub instance {
    unless ($instance) {
        my ($class) = @_;
        return bless({}, $class);
    }

    return $instance;
}

sub states {
    my ($self) = @_;

    return unless ref($self) eq 'NSMF::Proto';

    return [
        'dispatcher',

        ## Authentication
        'authenticate',
        'identify',

        # -> To Server
        'send_ping',
        'send_pong',

        # -> From Server
        'got_ping',
        'got_pong',
    ];
}

sub dispatcher {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    say "dispatcher";
}
################ AUTHENTICATE ###################
sub authenticate {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    $heap->{stage} = 'REQ';
}

sub identify {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    $heap->{stage} = 'SYN';     
}

################ END AUTHENTICATE ##################

################ KEEP ALIVE ###################
sub send_ping {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    return if $heap->{shutdown};

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';
}

sub send_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';
}

sub got_ping {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';
}

sub got_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';
}
################ END KEEP ALIVE ###################

1;
