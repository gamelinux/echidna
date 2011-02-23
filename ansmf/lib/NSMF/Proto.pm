package NSMF::Proto;

use strict;
use v5.10;

use POE;
use NSMF::Util;
use Data::Dumper;

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
        'authenticate',
        'identify',
        'send_ping',
        'send_pong',
        'got_ping',
        'got_pong',
    ];
}

sub dispatcher {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    my $action = '';
    given($request) {
        when(/FOUND/) {
            given($heap->{stage}) {
                when('REQ') {
                    $action = 'identify';
                } default: {
                    return;
                }
            }
        }
        when(/NSMF\/1.0 200 OK ACCEPTED/i) {
            if ($heap->{stage} eq 'SYN') {
                $heap->{stage} = 'EST';
                say 'We are wired in baby!';
                $kernel->yield('run');
                return;
            } 
        }
        when(/PONG/) {
           $action = 'got_pong'; 
        }
    }
    $kernel->yield($action) if $action;

    $kernel->delay(send_ping => 30) unless $heap->{shutdown};

}

# Stage REQ
sub authenticate {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    my $nodename = $heap->{nodename};
    my $netgroup = $heap->{netgroup};

    $heap->{stage} = 'REQ';
    $heap->{server}->put("AUTH $nodename $netgroup NSMF/1.0");
}

# Stage SYN
sub identify {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    my ($nodename, $key) = ($heap->{nodename}, '1234');
    print_status 'Identifying..';
    print_error('Nodename, Secret not defined on Identification Stage') unless defined_args($nodename, $key);

    $heap->{stage} = 'SYN';     
    $heap->{server}->put("ID $key $nodename NSMF/1.0");
}

sub send_ping {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    return if $heap->{shutdown};

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';

    print_status "Sending PING..";

    $heap->{server}->put("PING " .time(). " NSMF/1.0");
    $heap->{ping_sent} = time();
}

sub got_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    print_status "Got PONG ";
    $heap->{ping_recv} = time();
    if ($heap->{ping_sent}) {
        say "Latency" if ($heap->{ping_sent} - $heap->{ping_recv}) > 5;
    }
}

sub got_ping {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
}

sub send_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';

    $heap->{server}->put("PONG " .time(). " NSMF/1.0");
    print_status "Sending PONG..";
    $heap->{ping_sent} = time();
}

sub is_alive {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $interval = time() - $heap->{ping_recv};
    if ( $interval > 4) {
        say "There is latency..";
    }
}

sub got_ok {
    my ($kernel, $arg) = @_[KERNEL, ARG0];
    say "Got OK!: $arg";
}

sub send_data {
    
}

1;
