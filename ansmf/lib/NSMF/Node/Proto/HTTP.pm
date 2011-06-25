package NSMF::Node::Proto::HTTP;

use strict;
use v5.10;

use POE;
use NSMF::Util;
use NSMF::Common::Logger;
use Data::Dumper;
use Compress::Zlib;
use MIME::Base64;

my $instance;
my $logger = NSMF::Common::Logger->new();

sub instance {
    unless ($instance) {
        my ($class) = @_;
        return bless({}, $class);
    }

    return $instance;
}

sub states {
    my ($self) = @_;

    return if ( ref($self) ne __PACKAGE__ );

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

    $logger->warn("  [error] Response is Empty") if ( ! defined($request) );

    my $action = '';
    given($heap->{stage}) {
        when(/REQ/) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED/i) { 
                    $action = 'identify';
                    $logger->debug('  [response] = OK ACCEPTED'); }
                when(/^NSMF\/1.0 UNAUTHORIZED/i) { 
                    $logger->debug('  [response] = NOT ACCEPTED'); 
                    return; }
                default: {
                    $logger->debug(" UNKNOWN RESPONSE: $request");
                    return; }
            }
        }
        when(/SYN/i) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED/i) { 
                    $heap->{stage} = 'EST';
                    $logger->debug('  [response] = OK ACCEPTED');
                    $kernel->yield('run');
                    $kernel->delay(ping => 3);
                    return; }
                when(/^NSMF\/1.0 401 UNSUPPORTED/i) { 
                    $logger->debug('  [response] = UNSUPPORTED'); 
                    return; }
                default: {
                    $logger->debug(" UNKNOWN RESPONSE: $request");
                    return; }
            }
        }
        when(/EST/i) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED\r\n$/i) {
                     $logger->debug('  -> EST ACCEPTED');
                }
                when(/^PONG (\d)+ NSMF\/1.0\r\n$/i) {
                    $action = 'got_pong'; }
                when(/^PING (\d)+ NSMF\/1.0\r\n$/i) {
                    $action = 'got_ping'; }
                when(/POST/i) {
                    my $req = parse_request(post => $request);
    
                    unless (ref $req eq 'POST') {
                        $logger->debug('Failed to parse');
                        return;
                    }
                    my $data = uncompress(decode_base64( $req->{data} ));
                    $logger->debug('Method: ' . $req->{method});
                    $logger->debug('Params: ' . $req->{param});
                    $logger->debug(Dumper($data)); 
                    }
                default: {
                    $logger->debug(" UNKNOWN RESPONSE: $request");
                    $logger->debug(Dumper($request));
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

    $logger->debug('-> Identifying ' .$nodename);
    $logger->fatal('Nodename, Secret not defined on Identification Stage') if ( ! defined_args($nodename) );

    $heap->{stage} = 'SYN';     
    $heap->{server}->put("ID $nodename NSMF/1.0");
}

################ END AUTHENTICATE ##################

################ KEEP ALIVE ###################
sub send_ping {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    return if $heap->{shutdown};

    # Verify Established Connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('    -> Sending PING...');

    my $ping_sent = time();
    $heap->{server}->put("PING " .$ping_sent. " NSMF/1.0\r\n");
    $heap->{ping_sent} = $ping_sent;
}

sub send_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return if ( $heap->{stage} ne 'EST' );

    my $ping_time = time();
    $heap->{server}->put("PONG " .$ping_time. " NSMF/1.0\r\n");
    $logger->debug('    -> Sending PONG...');
    $heap->{ping_sent} = $ping_time;
}

sub got_ping {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('    <- Got PING ');
    $heap->{ping_recv} = time();

    $kernel->yield('send_pong');
}

sub got_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('    <- Got PONG ');
    $heap->{pong_recv} = time();

    $kernel->delay(send_ping => 60);
}

################ END KEEP ALIVE ###################


1;
