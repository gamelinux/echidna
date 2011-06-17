package NSMF::Proto::HTTP;

use strict;
use v5.10;

use POE;
use NSMF::Common::Util;
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

    return unless ref($self) eq 'NSMF::Proto::HTTP';

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
                when(/^NSMF\/1.0 UNAUTHORIZED/i) { 
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
                when(/^NSMF\/1.0 401 UNSUPPORTED/i) { 
                    say "  [response] = UNSUPPORTED"; 
                    return; }
                default: {
                    say " UNKNOWN RESPONSE: $request";
                    return; }
            }
        }
        when(/EST/i) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED\r\n$/i) {
                     say "  -> EST ACCEPTED";
                }
                when(/^PONG (\d)+ NSMF\/1.0\r\n$/i) {
                    $action = 'got_pong'; }
                when(/^PING (\d)+ NSMF\/1.0\r\n$/i) {
                    $action = 'got_ping'; }
                when(/POST/i) {
                    my $req = parse_request(post => $request);
    
                    unless (ref $req eq 'POST') {
                        say "Failed to parse";
                        return;
                    }
                    my $data = uncompress(decode_base64( $req->{data} ));
                    say "Method: " .$req->{method};
                    say "Params: " .$req->{param};
#                    say Dumper $data; 
                    }
                default: {
                    say " UNKNOWN RESPONSE: $request";
#                    say Dumper $request;
                    return; }
            }
        }
    }

    $kernel->yield($action) if $action;
}
################ AUTHENTICATE ###################
sub authenticate {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    $heap->{stage} = 'REQ';
    my $agent    = $heap->{agent};
    my $secret   = $heap->{secret};

    my $payload = "AUTH $agent $secret NSMF/1.0";
    $heap->{server}->put($payload);
}

sub identify {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    my $nodename = $heap->{nodename};
    my $payload = "ID " .$nodename. " NSMF/1.0";
    say '-> Identifying ' .$nodename;
    print_error 'Nodename, Secret not defined on Identification Stage' unless defined_args($nodename);

    $heap->{stage} = 'SYN';     
    $heap->{server}->put("ID $nodename NSMF/1.0");
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
    $heap->{server}->put("PING " .$ping_sent. " NSMF/1.0\r\n");
    $heap->{ping_sent} = $ping_sent;
}

sub send_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';

    my $ping_time = time();
    $heap->{server}->put("PONG " .$ping_time. " NSMF/1.0\r\n");
    say "    -> Sending PONG..";
    $heap->{ping_sent} = $ping_time;
}

sub got_ping {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';

    say "    <- Got PING ";
    $heap->{ping_recv} = time();

    $kernel->yield('send_pong');
}

sub got_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';

    say "    <- Got PONG ";
    $heap->{pong_recv} = time();

    $kernel->delay(send_ping => 60);
}

################ END KEEP ALIVE ###################


1;
