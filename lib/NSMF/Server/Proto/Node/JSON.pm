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

    $handle->push_read( json => sub { $self->dispatcher(@_); } );
}

sub write {
    my ($self, $handle, $json) = @_;

    return if ( ref($json) ne 'HASH' );

    $handle->push_write( json => $json );
    $handle->push_write( "\n" );
}

sub dispatcher {
    my ($self, $handle, $json) = @_;

    my $action = json_action_get($json);

    # obtain node from handle
    my $node = $self->node_from_handle($handle);
    return if ( ! defined($node) );

    # check if we should respond first
    if ( defined($action->{callback}) ) {
        #if ($action->{method} eq 'has_pcap') {
        #    $heap->{pcap} = $action->{callback}($self, $kernel, $heap, $json);
        #    return;
        #}
        return $action->{callback}($self, $node, $json);
    }

    if ( exists($json->{method}) ) {
        my $ret;

        eval {
            $ret = json_result_create($json, $self->_execute_method($json->{method}, $node, $json));
        };

        if ( ref($@) ) {
            $ret = json_error_create($json, $@->{object});
        }

        if( defined($ret) ) {
            $self->write($handle, $ret);
        }
    }
    else {
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
    my ($self, $method, $node, $json) = @_;

    # ensure the method is defined
    if ( ! defined($self->{methods}{ $method }) )
    {
        die JSONRPC_NSMF_BAD_REQUEST;
    }

    # ensure the caller has sufficient privilege
    if ( $self->{methods}{ $method }{acl} ) {
        if ( $node->{details}{acl} < $self->{methods}{$method}{acl} ) {
            #TODO: insufficient privileges
            die JSONRPC_NSMF_BAD_REQUEST;
        }
    }

    $logger->debug('Calling: ' . $method);

    # finally call the method now
    return $self->{methods}{ $method }{func}->($node, $json);
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
    my ($self, $node, $json) = @_;

    if ( $node->{status} ne 'REQ' ) {
        die { object => JSONRPC_NSMF_UNAUTHORIZED };
    }

    $logger->debug('Authentication Request');

    # authenticate the node
    eval {
        json_validate($json, ['$agent','$secret']);
    };

    if ( ref($@) ) {
        $logger->error('Incomplete JSON AUTH request. ' . $@->{message});
        die $@;
    }

    my $agent  = $json->{params}{agent};
    my $secret = $json->{params}{secret};

    my $agent_details = {};

    eval {
        $agent_details = NSMF::Server::AuthMngr->authenticate_agent($agent, $secret);
    };

    if ($@) {
        $logger->error('Agent authentication unsupported: ', $@);
        die { object => JSONRPC_NSMF_AUTH_UNSUPPORTED };
    }

    $node->{agent} = $agent;
    $node->{status} = 'ID';
    $node->{agent_details} = $agent_details;

    $logger->debug('Agent authenticated: ' . $agent);

    return $agent_details;
}

sub identify {
    my ($self, $node, $json) = @_;

    if ( $node->{status} ne 'ID' ) {
        die { object => JSONRPC_NSMF_UNAUTHORIZED };
    }

    eval {
        json_validate($json, ['$module', '$netgroup']);
    };

    if ( ref $@ ) {
        $logger->error('Incomplete JSON ID request. ' . $@->{message});
        die $@;
    }

    # if we have a session ID we are already registered
    if ($node->{session_key}) {
        $self->write($node->{handle}, json_error_create($json, JSONRPC_NSMF_IDENT_REGISTERED));
        return;
    }

    my $node_name = trim(lc($json->{params}{module}));
    my $node_type = trim(lc($json->{params}{type}));
    my $netgroup = trim(lc($json->{params}{netgroup}));

    my $node_details = {};

    # grab the node/module details
    eval {
        $node_details = NSMF::Server::AuthMngr->authenticate_node($node_name, $node_type);
    };

    if ( $@ ) {
        $logger->error('Unknown node name "'. $node_name . '" of type "' . $node_type . '"');
        die { object => JSONRPC_NSMF_IDENT_INCONSISTENT };
    }

    if ( ! ($node_type ~~ @$modules) ) {
        die { object=> JSONRPC_NSMF_IDENT_UNSUPPORTED };
    }

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
        die $@;
    }

    my $db = NSMF::Server->database();
    $db->update({ node => { state => 1 } }, { id => $node->{details}{id} });

    return $node_details;
}

sub ping {
    my ($self, $node, $json) = @_;

    # ensure we are authenticated
    if ( ! $self->_is_authenticated($node) ) {
        die JSONRPC_NSMF_BAD_REQUEST;
    }

    $logger->debug('  <- Got PING');

#    $kernel->post(transfer_mngr => 'queue_status');

    eval {
        json_validate($json, ['$timestamp']);
    };

    if ( ref $@ ) {
        $logger->error('Incomplete PING request. ' . $@->{message});
        die $@;
    }

    my $ping_time = $json->{params}{timestamp};

    $node->{ping_recv} = $ping_time if $ping_time;

    $logger->debug('  -> Sending PONG');

    return { timestamp => time() };
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
