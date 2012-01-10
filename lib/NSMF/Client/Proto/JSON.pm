#
# This file is part of the NSM framework
#
# Copyright (C) 2010-2012, Edward Fjellskål <edwardfjellskaal@gmail.com>
#                          Eduardo Urias    <windkaiser@gmail.com>
#                          Ian Firns        <firnsy@securixlive.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License Version 2 as
# published by the Free Software Foundation.  You may not use, modify or
# distribute this program under any other version of the GNU General
# Public License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
package NSMF::Client::Proto::JSON;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Data::Dumper;
use Carp;
use POE;

#
# NSMF INCLUDES
#
use NSMF::Common::Util;
use NSMF::Common::JSON;

#
# GLOBALS
#
my $instance;
my $logger = NSMF::Common::Registry->get('log') 
    // carp 'Got an empty config object from Registry';

sub instance {
    unless ($instance) {
        my ($class) = @_;

        return bless({}, $class);
    }

    return $instance;
}

sub states {
    my ($self) = @_;

    return if (ref($self) ne __PACKAGE__ );

    return [
        'dispatcher',

        ## Authentication
        'authenticate',

        # -> To Server
        'send_ping',
        'send_pong',
        'post',
        'get',

        # -> From Server
        'got_ping',
        'got_pong',
    ];
}

sub dispatcher {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    my $json = {};
    my $action = undef;

    eval {
        $json = json_decode($request);
        $action = json_action_get($json);
    };

    if ( $@ ) {
        $logger->error('Invalid JSON request.');
        return;
    }

    # check if we should responsd first

    if( defined($action->{callback}) )
    {
        # fire the callback providing:
        #   1. ourself (self)
        #   2. POE kernel
        #   3. POE connection heap
        #   4. JSON response
        return $action->{callback}($self, $kernel, $heap, $json);
    }

    # deal with notifications and method invocations
    given($heap->{stage}) {
        when(/REQ/) {
            given($action->{method}) {
                default: {
                    $logger->debug("UNKNOWN: $request");
                    return;
                }
            }
        }
        when(/SYN/i) {
            given($action->{method}) {
                default: {
                    $logger->debug("UNKNOWN: $request");
                    return;
                }
            }
        }
        when(/EST/i) {
            given($action->{method}) {
                when(/^ping/i) {
                    $kernel->yield('got_ping');
                }
                default: {
                    $logger->debug(" UNKNOWN RESPONSE: $request");
                    return;
                }
            }
        }
    }
}

################ AUTHENTICATE ###################
sub authenticate {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    $heap->{stage} = 'REQ';

    my $payload = json_message_create("authenticate", {
        "client" => $heap->{name},
        "secret" => $heap->{secret}
    }, sub {
        my ($self, $kernel, $heap, $json) = @_;

        if ( defined($json->{result}) ) {
            # store our unique agent ID
            $heap->{client_id} = $json->{result}{id};
            $kernel->call('console', 'put_output', 'Authenticated, ID: ' . $heap->{client_id});

            $heap->{stage} = 'EST';
            $kernel->post('console', 'load_session');
        }
        elsif ( defined($json->{error}) ) {
            $logger->debug('Authentication NOT ACCEPTED!');
            $kernel->call('console', 'put_output', 'Authentication FAILED');
        }
        else {
            $logger->debug(Dumper($json));
            $logger->debug('UNKNOWN Authentication Response', $response);
        }
    });

    $heap->{server}->put(json_encode($payload));
}
################ END AUTHENTICATE ##################

################ KEEP ALIVE ###################
sub send_ping {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $self = shift;

    return if $heap->{shutdown};

    # verify established connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('-> Sending PING..');

    my $ping_sent = time();

    my $payload = json_method_create("ping", {
        "timestamp" => $ping_sent
    }, sub {
        my ($self, $kernel, $heap, $json) = @_;

        if ( defined($json->{result}) )
        {
            $kernel->yield('got_pong');
        }
    });

    $heap->{server}->put(json_encode($payload));
    $heap->{ping_sent} = $ping_sent;
}

sub send_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # verify established connection
    return if ( $heap->{stage} ne 'EST' );

    my $ping_time = time();
    $heap->{server}->put("PONG " .$ping_time. " NSMF/1.0\r\n");
    $logger->debug('-> Sending PONG...');
    $heap->{ping_sent} = $ping_time;
}

sub got_ping {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # verify established connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('<- Got PING ');
    $heap->{ping_recv} = time();

    $kernel->yield('send_pong');
}

sub got_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # verify established connection
    return if ( $heap->{stage} ne 'EST' );

    $heap->{pong_recv} = time();

    my $latency = $heap->{pong_recv} - $heap->{ping_sent};

    $logger->debug('<- Got PONG ' . (($latency > 3) ? ( "Latency (" .$latency. "s)" ) : ""));

    $kernel->delay(send_ping => 60);
}

################ END KEEP ALIVE ###################

sub post {
    my ($kernel, $heap, $method, $data, $callback) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
    my $self = shift;

    return if $heap->{shutdown};

    # verify established connection
    return if ( $heap->{stage} ne 'EST' );

#    $logger->debug('-> Sending POST...');

    # TODO: validate type croak on fail
    #if ( ref($type) ) {
    #   my %hash = %$data;
    #   $type = keys %hash;
    #   $data = $hash{$type};
    #}

    my $payload = json_encode(json_message_create($method, $data, $callback));

    $heap->{server}->put($payload);

#    $logger->debug('Data Size: ' . length($payload));
}

sub get {
    my ($kernel, $heap, $data, $callback) = @_[KERNEL, HEAP, ARG0, ARG1];
    my $self = shift;

    return if $heap->{shutdown};

    # verify established connection
    return if ( $heap->{stage} ne 'EST' );

#    $logger->debug('-> Sending GET...');

    # TODO: validate type croak on fail
    #if ( ref($type) ) {
    #   my %hash = %$data;
    #   $type = keys %hash;
    #   $data = $hash{$type};
    #}

    my $payload = json_encode(json_message_create('get', $data, $callback));

    $heap->{server}->put($payload);

#    $logger->debug('Data Size: ' . length($payload));
}

1;
