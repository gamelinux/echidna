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
use Compress::Zlib;
use Data::Dumper;
use Carp;
use Date::Format;
use POE;
use POE::Session;
use POE::Wheel::Run;
use POE::Filter::Reference;

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


#
# NODE tracking
#
my $nodes = {};

sub instance {
    return $instance if ( $instance );

    my ($class) = @_;
    return bless({}, $class);
}

sub states {
    my ($self) = @_;

    return if ( ref($self) ne __PACKAGE__ );

    return [
        'dispatcher',
        'authenticate',
        'identify',
        'ping',
        'post',
        'get',

# Server -> Node
        'has_pcap',

        'node_registered',
        'node_unregistered',
    ];
}

sub node_registered {
    my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];

    # update node status once the ID has been resolved
    if ( defined($heap->{module_details}{id}) ) {
        my $db = NSMF::Server->database();
        $db->update({ node => { state => 1 } }, { id => $heap->{module_details}{id} });

        # add session->ID() to node ID map
        my $nodes = NSMF::Server->instance()->nodes();
        $nodes->{ $heap->{module_details}{id} } = $session->ID();
    }
}

sub node_unregistered {
    my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];

    if ( defined($heap->{module_details}{id}) ) {
        my $db = NSMF::Server->database();
        $db->update({ node => { state => 0 } }, { id => $heap->{module_details}{id} });

        # remove session->ID() to node ID map
        my $nodes = NSMF::Server->instance()->nodes();
        $nodes->{ $heap->{module_details}{id} } = $session->ID();
    }
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
        $logger->error('Invalid JSON request');
        $logger->debug($request);
        return;
    }

    # check if we should respond first
    if ( defined($action->{callback}) ) {

        # fire the callback providing
        #   1. ourself
        #   2. POE kernel
        #   3. POE connection heap
        #   4. JSON response

        #if ($action->{method} eq 'has_pcap') {
        #    $heap->{pcap} = $action->{callback}($self, $kernel, $heap, $json);
        #    return;
        #}
        return $action->{callback}($self, $kernel, $heap, $json);
    }

    if ( exists($json->{method}) ) {
        my $action = $json->{method};

        if( $action ~~ ['authenticate', 'identify', 'get', 'ping', 'post'] ) {
            $kernel->yield($action, $json);
        }
        else {
            $logger->debug(Dumper($json));
            $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_BAD_REQUEST));
        }
    }
}

sub authenticate {
    my ($kernel, $session, $heap, $json) = @_[KERNEL, SESSION, HEAP, ARG0];
    my $self = shift;

    if ( $heap->{status} ne 'REQ' ) {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_UNAUTHORIZED));
        return;
    }

    $logger->debug( "  -> Authentication Request");

    # authenticate the node
    eval {
        json_validate($json, ['$agent','$secret']);
    };

    if ( ref $@ ) {
      $logger->error('Incomplete JSON AUTH request. ' . $@->{message});
      $heap->{client}->put($@->{object});
      return;
    }

    my $agent  = $json->{params}{agent};
    my $secret = $json->{params}{secret};

    my $agent_details = {};

    eval {
        $agent_details = NSMF::Server::AuthMngr->authenticate_agent($agent, $secret);
    };

    if ($@) {
        $logger->error('Agent authentication unsupported: ', $@);
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_AUTH_UNSUPPORTED));
        return;
    }

    $heap->{agent} = $agent;
    $heap->{status} = 'ID';
    $heap->{agent_details} = $agent_details;

    $logger->debug("Agent authenticated: $agent");

    $heap->{client}->put(json_result_create($json, $agent_details));
}

sub identify {
    my ($kernel, $session, $heap, $json) = @_[KERNEL, SESSION, HEAP, ARG0];
    my $self = shift;

    if ( $heap->{status} ne 'ID' ) {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_UNAUTHORIZED));
        return;
    }

    eval {
        json_validate($json, ['$module', '$netgroup']);
    };

    if ( ref $@ ) {
        $logger->error('Incomplete JSON ID request. ' . $@->{message});
        $heap->{client}->put($@->{object});
        return;
    }

    # if we have a session ID we are already registered
    if ($heap->{session_key}) {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_IDENT_REGISTERED));
        return;
    }

    my $module_name = trim(lc($json->{params}{module}));
    my $module_type = trim(lc($json->{params}{type}));
    my $netgroup = trim(lc($json->{params}{netgroup}));

    my $module_details = {};

    # grab the node/module details
    eval {
        $module_details = NSMF::Server::AuthMngr->authenticate_node($module_name, $module_type);
    };

    if ( $@ ) {
        $logger->error('Unknown node name "'. $module_name . '" of type "' . $module_type . '"');
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_IDENT_INCONSISTENT));
        return;
    }

    if ($module_type ~~ @$modules) {
        $logger->debug("-> " .uc($module_type). " supported!");

        $heap->{name} = $module_name;
        $heap->{session_key} = 1;
        $heap->{status}     = 'EST';
        $heap->{module_details} = $module_details;

        eval {
            $heap->{module} = NSMF::Server::ModMngr->load(uc($module_type), 255); # full ACL priveleges applied
        };

        if ($@) {
            $logger->error('Could not load module type: ' . $module_type);
            $logger->debug($@);
        }

        # generate the session key
        $heap->{session_key} = $_[SESSION]->ID;

        if (defined $heap->{module}) {
            $logger->debug("----> Module Call <----");

            $kernel->yield('node_registered');

            $heap->{client}->put(json_result_create($json, $module_details));
            #$kernel->yield('has_pcap'); # DEBUG
            return;

            #
            # TODO: remove, or are we looking at running modules in separate forks?
#            my $child = POE::Wheel::Run->new(
#                Program => sub { $heap->{module}->run  },
#                StdoutFilter => POE::Filter::Reference->new(),
#                StdoutEvent => "child_output",
#                StderrEvent => "child_error",
#                CloseEvent  => "child_close",
#            );
#
#            $kernel->sig_child($child->PID, 'child_signal');
#            $heap->{children_by_wid}{$child->ID} = $child;
#            $heap->{children_by_pid}{$child->PID} = $child;
        }
    }
    else {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_IDENT_UNSUPPORTED));
    }
}

sub ping {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    $logger->debug("  <- Got PING");

    $kernel->post(transfer_mngr => 'queue_status');
    eval {
        json_validate($json, ['$timestamp']);
    };

    if ( ref $@ ) {
      $logger->error('Incomplete PING request. ' . $@->{message});
      $heap->{client}->put($@->{object});
      return;
    }

    my $ping_time = $json->{params}{timestamp};

    $heap->{ping_recv} = $ping_time if $ping_time;

    if ( $heap->{status} ne 'EST' || ! $heap->{session_key}) {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_UNAUTHORIZED));
        return;
    }

    $logger->debug('  -> Sending PONG');

    my $response = json_result_create($json, {
        "timestamp" => time()
    });

    $heap->{client}->put($response);
}

#sub child_output {
#    my ($kernel, $heap, $output) = @_[KERNEL, HEAP, ARG0];
#    $logger->debug(Dumper($output));
#}

#sub child_error {
#    $logger->error("Child Error: $_[ARG0]");
#}

#sub child_signal {
#    my $heap = $_[HEAP];
#    #$logger->debug("   * PID: $_[ARG1] exited with status $_[ARG2]");
#    my $child = delete $heap->{children_by_pid}{$_[ARG1]};

#    return if ( ! defined($child) );

#    delete $heap->{children_by_wid}{$child->ID};
#}

#sub child_close {
#    my ($heap, $wid) = @_[HEAP, ARG0];
#    my $child = delete $heap->{children_by_wid}{$wid};

#    if ( ! defined($child) ) {
#    #    $logger->debug("Wheel Id: $wid closed");
#        return;
#    }

#    #$logger->debug("   * PID: " .$child->PID. " closed");
#    delete $heap->{children_by_pid}{$child->PID};
#}

sub post {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    if ( $heap->{status} ne 'EST' || ! $heap->{session_key}) {
        $heap->{client}->put(json_result_create($json, 'Bad request'));
        return;
    }

    eval {
        my ($ret, $response) = json_validate($json, ['$type', '$jobid', '%data']);
    };

    if ( ref($@) ) {
      $logger->error('Incomplete POST request. ' . $@->{message});
      $heap->{client}->put($@->{object});
      return;
    }

    $logger->debug('This is a POST to ' . $heap->{name});

    my $module = $heap->{module};

    my $ret = undef;

    eval {
        $ret = $module->process( $json->{params} );
    };

    my $response = '';

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
        $heap->{client}->put($response);
    }

    # broadcast to registered clients
    $kernel->call('broadcast', $module, $json);
}

#
# REQUEST INFORMATION FROM CONNECTED NODE
#
sub get {
    my ($kernel, $heap, $json, $callback) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
    my $self = shift;

    if ( $heap->{status} ne 'EST' || ! $heap->{session_key}) {
        return -1;
    }

    $logger->debug('This is a GET to ' . $heap->{name});

    my $ret = undef;

    my $response = '';

    my $payload = json_message_create('get', $json, $callback);

    # don't reply with empty strings
    $heap->{client}->put(json_encode($payload));
}

sub _is_authenticated {
    my $heap = shift;
    return 1 unless ( $heap->{status} ne 'EST' || ! $heap->{session_key});
}

sub has_pcap {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    unless (_is_authenticated($heap)) {
        #TODO: Notification error
        return;
    }

    my $params = {
        nodename => 'cxtracker',
        type     => 'pcap',
        filter  => { src_host => '127.0.0.1', dst_port => '22' },
    };

    my $payload = json_method_create("has_pcap", $params, sub {
        my ($self, $kernel, $heap, $json) = @_;

        if (defined($json->{result})) {
            $logger->debug("File Metadata Recevied");
            $kernel->post('transfer_mngr', 'catch', $json);
        } else {
            $logger->debug("Error: Expected file metadata from node");
            $logger->debug(Dumper $json);
        }


    });

    $heap->{client}->put(json_encode($payload));

}

1;
