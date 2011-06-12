package NSMF::Proto::JSON;

use strict;
use v5.10;

use POE;
use NSMF::Util;
use Data::Dumper;
use Compress::Zlib;
use MIME::Base64;

use JSON;

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

    return unless ref($self) eq 'NSMF::Proto::JSON';

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
    my $self = shift;

    say "  [error] Response is Empty" unless $request;

    my $json = {};

    eval {
        $json = decode_json($request);
    };

    if ( $@ ) {
        return;
    }

    my $method = $self->jsonrpc_result_method($json);
    my $action = "";

    given($heap->{stage}) {
        when(/REQ/) {
            given($method) {
                when(/^authenticate/i) {
                    if ( defined($json->{result}) ) {
                        $action = 'identify';
                        say "  [response] = OK ACCEPTED";
                    }
                    elsif ( defined($json->{error}) ) {
                        say "  [response] = NOT ACCEPTED";
                        return;
                    }
                    else {
                        say Dumper($json);
                        say "  UNKOWN AUTH RESPONSE: $request";
                        return;
                    }
                }
                default: {
                  say "  UNKOWN RESPONSE: $request";
                  return;
                }
            }
        }
        when(/SYN/i) {
            given($method) {
                when(/^identify/i) {
                    if ( defined($json->{result}) ) {
                        $heap->{stage} = 'EST';
                        say "  [response] = OK ACCEPTED";
                        $kernel->yield('run');
                        $kernel->delay('send_ping' => 3);
                        return;
                    }
                    else {
                        say "  [response] = UNSUPPORTED";
                        return;
                    }
                }
                default: {
                  say "  UNKOWN RESPONSE: $request";
                  return;
                }
            }
        }
        when(/EST/i) {
            given($method) {
                when(/^ping/i) {
                    if ( defined($json->{result}) )
                    {
                        $action = 'got_pong';
                    }
                    else
                    {
                        $action = "got_ping";
                    }
                }
                default: {
                    say " UNKNOWN RESPONSE: $request";
                    return;
                }
            }
        }
    }

    $kernel->yield($action) if $action;
}

################ AUTHENTICATE ###################
sub authenticate {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    $heap->{stage} = 'REQ';
    my $agent    = $heap->{agent};
    my $secret   = $heap->{secret};

    my $payload = $self->jsonrpc_method_create("authenticate", {
      "agent" => $agent,
      "secret" => $secret
    });

    $heap->{server}->put(encode_json($payload));
}

sub identify {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    my $nodename = $heap->{nodename};

    my $payload = $self->jsonrpc_method_create("identify", {
      "module" => $nodename,
      "netgroup" => "test"
    });

    say '-> Identifying ' . $nodename;

    print_error 'Nodename, Secret not defined on Identification Stage' unless defined_args($nodename);

    $heap->{stage} = 'SYN';     
    $heap->{server}->put(encode_json($payload));
}

################ END AUTHENTICATE ##################

################ KEEP ALIVE ###################
sub send_ping {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $self = shift;

    return if $heap->{shutdown};

    # Verify Established Connection
    return unless $heap->{stage} eq 'EST';

    say "    -> Sending PING..";

    my $ping_sent = time();

    my $payload = $self->jsonrpc_method_create("ping", {
      "timestamp" => $ping_sent
    });

    $heap->{server}->put(encode_json($payload));
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

    $heap->{pong_recv} = time();

    my $latency = $heap->{pong_recv} - $heap->{ping_sent};

    say '    <- Got PONG ' . (($latency > 3) ? ( "Latency (" .$latency. "s)" ) : "");

    $kernel->delay(send_ping => 60);
}

################ END KEEP ALIVE ###################

# PRIVATE TODO

sub jsonrpc_method_create
{
    my ($self, $method, $params) = @_;

    my $id = int(rand(65536));

    while ( defined($self->{json_method_map}->{$id}) )
    {
        $id = int(rand(65536));
    }

    $self->{json_method_map}->{$id} = $method;

    return {
        "jsonrpc" => "2.0",
        "method" => $method,
        "params" => $params // '',
        "id" => $id
    };
}

sub jsonrpc_result_method
{
    my ($self, $json) = @_;

    if ( ! defined_args($json->{id}) &&
         ! defined_args($json->{method}) )
    {
        return "";
    }

    my $method = "";

    if ( defined($self->{json_method_map}->{$json->{id}}) )
    {
        $method = $self->{json_method_map}->{$json->{id}};
        delete($self->{json_method__map}->{$json->{id}});
    }
    elsif ( defined($json->{method}) )
    {
        $method = $json->{method};
    }

    return $method;
}

1;
