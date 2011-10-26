#
# This file is part of the NSM framework
#
# Copyright (C) 2010-2011, Edward Fjellskål <edwardfjellskaal@gmail.com>
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
package NSMF::Agent::Proto::JSON;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Compress::Zlib;
use Data::Dumper;
use MIME::Base64;
use Carp;
use POE;

#
# NSMF INCLUDES
#
use NSMF::Common::JSON;
use NSMF::Common::Util;
use NSMF::Common::Registry;

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
        'identify',

        # -> To Server
        'send_ping',
        'send_pong',
        'post',

        # -> From Server
        'got_ping',
        'got_pong',
        'got_get',
        'has_pcap',
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
        $logger->debug($json);
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
                when(/^get/i) {
                    $kernel->yield('got_get' => $json);
                }
                when(/^has_pcap/i) {
                    $kernel->yield('has_pcap' => $json);
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
    my $agent    = $heap->{agent};
    my $secret   = $heap->{secret};

    my $payload = json_message_create("authenticate", {
        "agent" => $agent,
        "secret" => $secret
    }, sub {
        my ($self, $kernel, $heap, $json) = @_;

        if ( defined($json->{result}) ) {
            # store our unique agent ID
            $heap->{agent_id} = $json->{result}{id};
            $logger->debug('Authenticated. Agent ID = ' . $heap->{agent_id});
            $kernel->yield('identify');
        }
        elsif ( defined($json->{error}) ) {
            $logger->debug('Authentication NOT ACCEPTED!');
        }
        else {
            $logger->debug(Dumper($json));
            $logger->debug('UNKNOWN Authentication Response', $response);
        }
    });

    $heap->{server}->put(json_encode($payload));
}

sub identify {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    my $nodename = $heap->{nodename};
    my $nodetype = $heap->{nodetype};

    my $payload = json_method_create("identify", {
        "module" => $nodename,
        "type" => $nodetype,
        "netgroup" => "test"
    }, sub {
        my ($self, $kernel, $heap, $json) = @_;

        if ( defined($json->{result}) ) {
             $heap->{node_id} = $json->{result}{id};
             $heap->{stage} = 'EST';
             $logger->debug('Synchronised. Node ID = ' . $heap->{node_id});
             $kernel->yield('run');
             $kernel->delay('send_ping' => 3);
        }
        else {
            $logger->debug('Synchronisation UNSUPPORTED');
        }
    });

    $logger->debug('-> Identifying ' . $nodename);

    $logger->fatal('Nodename, Secret not defined on Identification Stage') if ( ! defined_args($nodename) );

    $heap->{stage} = 'SYN';
    $heap->{server}->put(json_encode($payload));
}

################ END AUTHENTICATE ##################

################ KEEP ALIVE ###################
sub send_ping {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $self = shift;

    if ( ( ! $heap->{connected} ) ||
         ( $heap->{shutdown} ) ) {
        return;
    }

    # verify established connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('-> Sending PING..');

    my $ping_sent = time();

    my $payload = json_message_create("ping", {
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

#
# received a get from server
sub got_get {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    return if $heap->{shutdown};

    # verify established connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('-> Got GET...');

    # TODO: validate type croak on fail
    #if ( ref($type) ) {
    #   my %hash = %$data;
    #   $type = keys %hash;
    #   $data = $hash{$type};
    #}

    eval {
        json_validate($json, ['$type', '$jobid', '%data']);
    };

    if ( ref($@) ) {
      $logger->error('Incomplete GET request. ' . $@->{message});
      $heap->{client}->put($@->{object});
      return;
    }

    $logger->debug($json);

    my $response;
    my $ret;

    eval {
        $ret = $kernel->call('node', 'get', $json->{params});
    };


    if ( $@ ) {
        $logger->error($@);
        $response = json_error_create($json, {
            message => $@->{message},
            code => $@->{code}
        });
    }
    else {
        $response = json_result_create($json, $ret);
    }

    # don't reply with empty strings
    if ( $response ne '' ) {
        $heap->{server}->put($response);
    }
}

sub post {
    my ($kernel, $heap, $data, $callback) = @_[KERNEL, HEAP, ARG0, ARG1];
    my $self = shift;

    return if $heap->{shutdown};

    # verify established connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('-> Sending POST...');

    # TODO: validate type croak on fail
    #if ( ref($type) ) {
    #   my %hash = %$data;
    #   $type = keys %hash;
    #   $data = $hash{$type};
    #}

    my $payload = json_encode(json_message_create('post', $data, $callback));

    $heap->{server}->put($payload);

    $logger->debug('Data Size: ' . length($payload));
}

sub has_pcap {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];

    $logger->debug('  CHECKING IF THE DATA EXISTS ON THE NODE STORAGE');

    my $result_params =   {
        filter => $json->{params}{filter},
        checksum => '57239a761d86ff5430321193ab3fd9cbeba69a77',
        type => $json->{params}{type},
        size => 104528,
    };

    my $found = 1;
    if ($found) {
        $heap->{server}->put(json_result_create($json, $result_params));
        $logger->debug(' Meta data sent.');
    }
    # not
    else {
        $heap->{server}->put(json_error_create($json,
            JSONRPC_NSMF_PCAP_NOT_FOUND));
    }
}

1;
