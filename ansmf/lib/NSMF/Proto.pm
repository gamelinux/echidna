package NSMF::Proto;

use strict;
use v5.10;

use POE;
use NSMF::Util;
use Data::Dumper;
use Compress::Zlib;
use MIME::Base64;

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

    say "  [error] Response is Empty" unless $request;

    my $action = '';
    given($heap->{stage}) {
        when(/REQ/) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED/i) { 
                    $action = 'identify';
                    say "  [response] = OK ACCEPTED"; }
                when(/^NSMF\/1.0 UNSUPPORTED/i) { 
                    say "  [response] = NOT ACCEPTED"; 
                    return; }
                default: {
                    say " UNKNOWN RESPONSE: $request";
                    return; }
            }
        }
        when(/SYN/i) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED/i) { 
                    $heap->{stage} = 'EST';
                    say "  [response] = OK ACCEPTED";
                    $kernel->yield('run');
                    $kernel->delay(ping => 3);
                    return; }
                when(/^NSMF\/1.0 401 UNAUTHORIZED/i) { 
                    say "  [response] = UNAUTHORIZED"; 
                    return; }
                default: {
                    say " UNKNOWN RESPONSE: $request";
                    return; }
            }
        }
        when(/EST/i) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED/i) {
                     say "  -> EST ACCEPTED";
                }
                when(/^NSMF\/1.0 PONG (\d)+/i) {
                    $action = 'got_pong'; }
                when(/POST/i) {
                    my $req = parse_request(post => $request);
    
                    unless (ref $req eq 'POST') {
                        say "Failed to parse";
                        return;
                    }
                    my $data = uncompress(decode_base64( $req->{data} ));
                    say "Method: " .$req->{method};
                    say "Params: " .$req->{param};
                    say Dumper $data; }
                default: {
                    say " UNKNOWN RESPONSE: $request";
                    return; }
            }
        }
    }
    $kernel->yield($action) if $action;

#    $kernel->delay(send_ping => 5) unless $heap->{shutdown};

}
################ AUTHENTICATE ###################
sub authenticate {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    my $nodename = $heap->{nodename};
    my $netgroup = $heap->{netgroup};

    $heap->{stage} = 'REQ';
    $heap->{server}->put("AUTH $nodename $netgroup NSMF/1.0");
}

sub identify {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    my ($nodename, $key) = ($heap->{nodename}, '1234');
    say 'Identifying..';
    print_error('Nodename, Secret not defined on Identification Stage') unless defined_args($nodename, $key);

    $heap->{stage} = 'SYN';     
    $heap->{server}->put("ID $key $nodename NSMF/1.0");
}

################ END AUTHENTICATE ##################

################ KEEP ALIVE ###################
sub send_ping {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    return if $heap->{shutdown};

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';

    say "    -> Sending PING..";

    my $ping_sent = time();
    $heap->{server}->put("PING " .$ping_sent. " NSMF/1.0");
    $heap->{ping_sent} = $ping_sent;
}

sub send_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';

    my $ping_time = time();
    $heap->{server}->put("PONG " .$ping_time. " NSMF/1.0");
    say "Sending PONG..";
    $heap->{ping_sent} = $ping_time;
}

sub got_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    say "    <- Got PONG ";
    $heap->{ping_recv} = time();

    if ($heap->{ping_sent}) {
        say "Latency" if ($heap->{ping_sent} - $heap->{ping_recv}) > 5;
    }

    $kernel->delay(send_ping => 3);
}

sub got_ping {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
}

sub is_alive {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $interval = time() - $heap->{ping_recv};
    if ( $interval > 4) {
        say "There is latency..";
    }
}
################ END KEEP ALIVE ###################

sub parse_post {
    my ($request) = @_;
    my @data   = split '\s+', $request;

    return unless scalar @data == 4;

    return {
        method => $data[0],
        param  => $data[1],
        tail   => $data[2],
        data   => $data[3],
    };
}

sub parse_request {
    my ($type, $input) = @_;

    if (ref $type) {
        my %hash = %$type;
        $type = keys %hash;
        $input = $hash{$type};
    }
    my @types = (
        'auth',
        'get',
        'post',
    );

    return unless grep $type, @types;
    return unless defined $input;

    my @request = split '\s+', $input;
    given($type) {
        when(/AUTH/i) { 
            return bless { 
                method   => $request[0],
                nodename => $request[1],
                netgroup => $request[2],
                tail     => $request[3],
            }, 'AUTH';
        }
        when(/GET/i) {
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                query  => $request[4] // undef,
            }, 'POST';
        }
        when(/POST/i) {
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                data   => $request[4] // undef,
            }, 'POST';
        }
    }
}

1;
