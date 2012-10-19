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
package NSMF::Server::Proto::Node::JSON;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Carp;
use Compress::Zlib;
use Data::Dumper;
use Date::Format;
use Scalar::Util qw/weaken/;

#
# NSMF INCLUDES
#
use NSMF::Common::JSON;
use NSMF::Common::Registry;
use NSMF::Common::Util;
use NSMF::Server;
use NSMF::Server::AuthMngr;
use NSMF::Server::ConfigMngr;
use NSMF::Server::ModMngr;

#
# GLOBALS
#
my $instance;
my $config = NSMF::Server::ConfigMngr->instance;
my $modules = $config->modules() // [];
my $logger = NSMF::Common::Registry->get('log')
    // carp 'Got an empty config object from Registry';

sub instance {
    return $instance if ( $instance );

    my ($class) = @_;

    my $self = bless({
        methods => {},
    }, $class);

    $self->init();

    return $self;
}

sub init {
    my ($self) = @_;

    $self->_register_method('authenticate', 0, sub { $self->authenticate(@_); });
    $self->_register_method('identify', 0, sub { $self->identify(@_); });
    $self->_register_method('ping', 0, sub { $self->ping(@_); });
}

sub node_from_handle {
    my ($self, $handle) = @_;

    my $nodes = NSMF::Server->instance()->nodes();
    my $node = undef;

    if ( ref($handle) eq 'AnyEvent::Handle' ) {
        $node = $nodes->{ fileno( $handle->{fh} ) };
    }
    elsif ( ref($handle) eq 'AnyEvent::Socket' ) {
      $node = $nodes->{ fileno($handle) } // undef;
    }

    return $node;
}

sub read {
    my ($self, $handle) = @_;

    $handle->push_read( json => sub { 
        $self->dispatcher(@_);
    });
}

sub write {
    my ($self, $handle, $json) = @_;

    return if ref($json) ne 'HASH';

    $handle->push_write( json => $json );
    $handle->push_write( "\n" );
}

sub dispatcher {
    my ($self, $handle, $json) = @_;

    my $action = json_action_get($json);

    # obtain node from handle
    my $node = $self->node_from_handle($handle);
    return unless defined($node);

    # check if we should respond first
    if ( defined($action->{callback}) ) {
        #if ($action->{method} eq 'has_pcap') {
        #    $heap->{pcap} = $action->{callback}($self, $kernel, $heap, $json);
        #    return;
        #}
        return $action->{callback}($self, $node, $json);
    }
    # otherwise check if the requested method exists
    elsif ( exists($json->{method}) ) {
        my $ret;

        $self->_execute_method($json->{method}, $node, $json,
        sub { # on_success callback
            my ($json, $result) = @_;
            my $ret = json_result_create($json, $result);
            if( defined($ret) ) {
                $self->write($handle, $ret);
            }
        },
        sub { #on_error callback
            my ($json, $error) = @_;
            my  $ret = json_error_create($json, $error);

            if( defined($ret) ) {
                $self->write($handle, $ret);
            }
        });
    }
    # otherwise respond in error as appropriate
    elsif ( exists($json->{id}) ) {
        $self->write($handle, json_error_create($json, JSONRPC_NSMF_BAD_REQUEST));
    }
}

#
# PRIVATE METHODS
#

sub _register_method {
    my ($self, $method, $acl, $func) = @_;

    # check if the method is already defined
    return 0 if ( defined($self->{methods}{$method}) );

    $logger->debug('Registering node method: ' . $method);
    $self->{methods}{ $method } = {
        acl   => $acl,
        func  => $func,
    }
}

sub _register_methods {
    my ($self, $methods) = @_;

    return if ( ref($methods) ne 'ARRAY' );

    # add each method definition from the array
    foreach my $method ( @{ $methods } ) {
        $self->_register_method($method->{method}, $method->{acl}, $method->{func});
    }
}

sub _execute_method {
    my ($self, $method, $node, $json, $cb_success, $cb_error) = @_;

    # ensure the method is defined
    if ( ! defined($self->{methods}{ $method }) )
    {
        return $cb_error->($json, JSONRPC_NSMF_BAD_REQUEST);
    }

    # ensure the caller has sufficient privilege
    if ( $self->{methods}{ $method }{acl} ) {
        if ( $node->{details}{acl} < $self->{methods}{$method}{acl} ) {
            #TODO: insufficient privileges
            return $cb_error->($json, JSONRPC_NSMF_BAD_REQUEST);
        }
    }

    $logger->debug('Calling: ' . $method);

    # finally call the method now
    $self->{methods}{ $method }{func}->($node, $json, $cb_success, $cb_error);
}

sub _is_authenticated {
    my ($self, $node) = @_;

    return ( ( $node->{status} eq 'EST' ) &&
             ( $node->{session_key} ) );
}

#
# CORE METHODS
#

sub authenticate {
    my ($self, $node, $json, $cb_success, $cb_error) = @_;

    if ( $node->{status} ne 'REQ' ) {
        return $cb_error->($json, JSONRPC_NSMF_UNAUTHORIZED);
    }

    $logger->debug('Authentication Request');

    # authenticate the node
    eval {
        json_validate($json, ['$agent','$secret']);
    };

    if ( ref($@) ) {
        $logger->error('Incomplete JSON AUTH request. ' . $@->{message});
        return $cb_error->($json, $@);
    }

    my $agent  = $json->{params}{agent};
    my $secret = $json->{params}{secret};

    # TODO: weaken $node, $logger ?
    NSMF::Server::AuthMngr->authenticate_agent($agent, $secret,
      sub {
        my $agent_details = shift;

        $node->{agent} = $agent;
        $node->{status} = 'ID';
        $node->{agent_details} = $agent_details;

        $logger->debug('Agent authenticated: ' . $agent);

        weaken($node);
        weaken($logger);

        $cb_success->($json, $agent_details);
      },
      sub {
        $logger->error('Agent authentication unsupported: ', $@);
        weaken($logger);
        $cb_error->($json, { object => JSONRPC_NSMF_AUTH_UNSUPPORTED });
      }
    );
}

sub identify {
    my ($self, $node, $json, $cb_success, $cb_error) = @_;

    if ( $node->{status} ne 'ID' ) {
        return $cb_error->($json, { object => JSONRPC_NSMF_UNAUTHORIZED });
    }

    eval {
        json_validate($json, ['$module', '$netgroup']);
    };

    if ( ref($@) ) {
        $logger->error('Incomplete JSON ID request. ' . $@->{message});
        return $cb_error->($json, $@);
    }

    # if we have a session ID we are already registered
    if ($node->{session_key}) {
        $cb_error->($json, JSONRPC_NSMF_IDENT_REGISTERED);
        return;
    }

    my $node_name = trim(lc($json->{params}{module}));
    my $node_type = trim(lc($json->{params}{type}));
    my $netgroup = trim(lc($json->{params}{netgroup}));

    if ( ! ($node_type ~~ @$modules) ) {
        return $cb_error->($json, { object => JSONRPC_NSMF_IDENT_UNSUPPORTED });
    }

    # grab the node/module details
    NSMF::Server::AuthMngr->authenticate_node($node_name, $node_type,
      sub {
        my $node_details = shift;
        $logger->debug('-> ' . uc($node_type) . ' supported!');

        $node->{name} = $node_name;

        # generate the session key
        my @keyspace = ('a'..'z', 'A'..'Z', 0..9);
        $node->{session_key} = join('', map $keyspace[rand @keyspace], 0..32);

        $node->{status} = 'EST';
        $node->{details} = $node_details;

        eval {
            $node->{instance} = NSMF::Server::ModMngr->load(uc($node_type));

            $self->_register_methods( $node->{instance}->get_registered_methods() );
        };

        if ( ref($@) ) {
            $logger->error('Could not load node type: ' . $node_type);
            return $cb_error->($json, $@);
        }

        my $db = NSMF::Server->database();
        $db->update(node => { id => $node->{details}{id} }, { state => '1' });

        weaken($logger);
        weaken($node);
        weaken($db);

        $cb_success->($json, $node_details);
      },
      sub {
        my ($error) = @_;
        $logger->error('Unknown node name "'. $node_name . '" of type "' . $node_type . '"');
        $cb_error->($json, { object => JSONRPC_NSMF_IDENT_INCONSISTENT });
      }
    );
}

sub ping {
    my ($self, $node, $json, $cb_success, $cb_error) = @_;

    # ensure we are authenticated
    if ( ! $self->_is_authenticated($node) ) {
        return $cb_error->($json, JSONRPC_NSMF_BAD_REQUEST);
    }

    $logger->debug('  <- Got PING');

#    $kernel->post(transfer_mngr => 'queue_status');

    eval {
        json_validate($json, ['$timestamp']);
    };

    if ( ref $@ ) {
        $logger->error('Incomplete PING request. ' . $@->{message});
        return $cb_error->($json, $@);
    }

    my $ping_time = $json->{params}{timestamp};

    $node->{ping_recv} = $ping_time if $ping_time;

    $logger->debug('  -> Sending PONG');

    $cb_success->($json, { timestamp => time() });
}

#sub has_pcap {
#    my ($kernel, $heap) = @_[KERNEL, HEAP];
#
#    unless (_is_authenticated($heap)) {
#        #TODO: Notification error
#        return;
#    }
#
#    my $params = {
#        nodename => 'cxtracker',
#        type     => 'pcap',
#        filter  => { src_host => '127.0.0.1', dst_port => '22' },
#    };
#
#    my $payload = json_method_create("has_pcap", $params, sub {
#        my ($self, $kernel, $heap, $json) = @_;
#
#        if (defined($json->{result})) {
#            $logger->debug("File Metadata Recevied");
#            $kernel->post('transfer_mngr', 'catch', $json);
#        } else {
#            $logger->debug("Error: Expected file metadata from node");
#            $logger->debug(Dumper $json);
#        }
#
#
#    });
#
#    $heap->{client}->put(json_encode($payload));
#
#}

1;
