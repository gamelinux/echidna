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
use AnyEvent;
use Compress::Zlib;
use Data::Dumper;
use MIME::Base64;
use Carp;
use JSON;

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

sub new {
    my $class = shift;
    my $parent = shift;

    return bless {
        __parent  => $parent,
        __handle  => undef,
        __handler => {
            run           => undef,
            set_identity  => undef,
        },
        __stage   => 'REQ',
    }, $class;
}

sub set_parent {
    my ($self, $parent) = @_;

    $self->{__parent} = $parent;
}

sub set_handle {
    my ($self, $handle) = @_;

    $self->{__handle} = $handle;
}

sub read {
    my ($self) = @_;

    return if ( ! defined($self->{__handle}) );

    $self->{__handle}->push_read( json => sub { $self->dispatcher($_[1]); } );
}

sub write {
    my ($self, $data) = @_;

    return if ( ! defined($self->{__handle}) );
    return if ( ref($data) ne 'HASH' );

    $self->{__handle}->push_write( json => $data );
    $self->{__handle}->push_write( "\012" );
}

sub dispatcher {
    my ($self, $json) = @_;

    my $action = undef;

    eval {
        $action = json_action_get($json);
    };

    if ( $@ ) {
        $logger->error('Invalid JSON request.');
        $logger->debug($json);
        return;
    }

    # check if we should respond first

    if( defined($action->{callback}) )
    {
        # fire the callback providing:
        #   1. ourself (self)
        #   2. POE kernel
        #   3. POE connection heap
        #   4. JSON response
        return $action->{callback}($json);
    }

    # deal with notifications and method invocations
    given($self->{__stage}) {
        when(/REQ/) {
            given($action->{method}) {
                default: {
                    $logger->debug("UNKNOWN:", $json);
                    return;
                }
            }
        }
        when(/SYN/i) {
            given($action->{method}) {
                default: {
                    $logger->debug("UNKNOWN:", $json);
                    return;
                }
            }
        }
        when(/EST/i) {
            given($action->{method}) {
                when(/^ping/i) {
                    $self->got_ping();
                }
                when(/^get/i) {
                    $self->got_get($json);
                }
                when(/^has_pcap/i) {
                    $self->has_pcap($json);
                }
                default: {
                    $logger->debug(" UNKNOWN:", $json);
                    return;
                }
            }
        }
    }
}

#
# AUTHENTICATE
#
sub authenticate {
    my ($self) = @_;

    $self->{__stage} = 'REQ';

    my $agent    = $self->{__parent}{agent};
    my $secret   = $self->{__parent}{secret};

    my $payload = json_message_create('authenticate', {
        agent   => $agent,
        secret  => $secret
    }, sub { $self->authenticate_response_handler(@_); });

    $self->write($payload);
}

sub authenticate_response_handler {
    my ($self, $json) = @_;

    if ( defined($json->{result}{id}) ) {

        $self->{__parent}->set_identity({
            agent_id => $json->{result}{id}
        });

        $logger->debug('Authenticated. Agent ID = ' . $json->{result}{id});

        $self->identify();
    }
    elsif ( defined($json->{error}) ) {
        $logger->debug('Authentication NOT ACCEPTED!');
    }
    else {
        $logger->debug(Dumper($json));
        $logger->debug('UNKNOWN Authentication Response', $json);
    }
}

#
# IDENTIFY
#
sub identify {
    my $self = shift;

    my $nodename = $self->{__parent}{nodename};
    my $nodetype = $self->{__parent}{nodetype};

    my $payload = json_method_create('identify', {
        module    => $nodename,
        type      => $nodetype,
        netgroup  => 'test'
    }, sub{ $self->identify_response_handler(@_); });

    $logger->debug('-> Identifying ' . $nodename);

    $logger->fatal('Nodename, Secret not defined on Identification Stage') if ( ! defined_args($nodename) );

    $self->{__stage} = 'SYN';
    $self->write($payload);
}

sub identify_response_handler {
    my ($self, $json) = @_;

    if ( defined($json->{result}) ) {
        $self->{__parent}->set_identity({
            node_id => $json->{result}{id}
        });

        $self->{__stage} = 'EST';
        $logger->debug('Identified. Node ID = ' . $json->{result}{id});

#         $kernel->yield('run');

#         $kernel->delay('send_ping' => 3);
    }
    else {
        $logger->debug('Identification UNSUPPORTED');
    }
}

#
# KEEP ALIVE
#
sub send_ping {
    my ($self) = @_;

    # verify established connection
    return if ( $self->{__stage} ne 'EST' );

    $logger->debug('-> Sending PING..');

    my $ping_sent = time();

    my $payload = json_message_create('ping', {
        timestamp => $ping_sent
    }, $self->got_pong);

    $self->write($payload);
    $self->{ping_sent} = $ping_sent;
}

sub got_pong {
    my ($self, $json) = @_;

    # verify established connection
    return if ( $self->{__stage} ne 'EST' );

    $self->{pong_recv} = time();

    my $latency = $self->{pong_recv} - $self->{ping_sent};

    $logger->debug('<- Got PONG ' . (($latency > 3) ? ( "Latency (" .$latency. "s)" ) : ""));

#    $kernel->delay(send_ping => 60);
}

################ END KEEP ALIVE ###################

#
# received a get from server
sub got_get {
    my ($self, $json) = shift;

    # verify established connection
    return if ( $self->{__stage} ne 'EST' );

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
      return;
    }

    $logger->debug("WOOT", $json);

    my $response;
    my $ret;

#    eval {
#        $ret = $kernel->call('node', 'get', $json->{params});
#    };


#    if ( $@ ) {
#        $logger->error($@);
#        $response = json_error_create($json, {
#            message => $@->{message},
#            code => $@->{code}
#        });
#    }
#    else {
#        $response = json_result_create($json, $ret);
#    }

    # don't reply with empty strings
#    if ( $response ne '' ) {
#        $heap->{server}->put($response);
#    }
}

# send message to server

sub post {
    my ($self, $method, $data, $callback) = @_;

    # verify established connection
    return if ( $self->{__stage} ne 'EST' );

    $logger->debug('-> Sending POST...');

    # TODO: validate type croak on fail
    #if ( ref($type) ) {
    #   my %hash = %$data;
    #   $type = keys %hash;
    #   $data = $hash{$type};
    #}

    my $payload = json_message_create($method, $data, $callback);

    $self->write($payload);

    $logger->debug('Data Size: ' . length($payload));
}

sub has_pcap {
    my ($self, $json) = @_;

    $logger->debug('  CHECKING IF THE DATA EXISTS ON THE NODE STORAGE');

    my $result_params =   {
        filter => $json->{params}{filter},
        checksum => '57239a761d86ff5430321193ab3fd9cbeba69a77',
        type => $json->{params}{type},
        size => 104528,
    };

    my $found = 1;

    if ($found) {
        $self->write(json_result_create($json, $result_params));
        $logger->debug(' Meta data sent.');
    }
    # not
    else {
        $self->write(json_error_create($json,
            JSONRPC_NSMF_PCAP_NOT_FOUND));
    }
}

1;
