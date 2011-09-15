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
package NSMF::Server::Proto::JSON;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Compress::Zlib;
use Data::Dumper;
use Date::Format;
use MIME::Base64;
use POE;
use POE::Session;
use POE::Wheel::Run;
use POE::Filter::Reference;

#
# NSMF INCLUDES
#
use NSMF::Common::JSON;
use NSMF::Common::Logger;
use NSMF::Common::Util;
use NSMF::Server;
use NSMF::Server::AuthMngr;
use NSMF::Server::ConfigMngr;
use NSMF::Server::ModMngr;
use NSMF::Server::Action;


#
# GLOBALS
#
my $instance;
my $config = NSMF::Server::ConfigMngr->instance;
my $modules = $config->modules() // [];
my $logger = NSMF::Common::Logger->new();

sub instance {
    return $instance if ( $instance );

    my ($class) = @_;
    return bless({}, $class);
}

sub states {
    my ($self) = @_;

    return if ( ref($self) ne 'NSMF::Server::Proto::JSON' );

    return [
        'dispatcher',
        'authenticate',
        'identify',
        'ping',
        'post',
        'send_ping',
        'get',

# Server -> Node
        'has_pcap'
#        'child_output',
#        'child_error',
#        'child_signal',
#        'child_close',
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
    if( $heap->{type} eq 'NODE' ) {
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

        $logger->debug("Agent authenticated: $agent");

        $heap->{client}->put(json_result_create($json, $agent_details));
    }
    # otherwise we are authenticating clients
    else {
        eval {
            json_validate($json, ['$client','$secret']);
        };

        if ( ref $@ ) {
          $logger->error('Incomplete JSON AUTH request. ' . $@->{message});
          $heap->{client}->put($@->{object});
          return;
        }

        my $client = $json->{params}{client};
        my $secret = $json->{params}{secret};

        my $client_details = {};

        eval {
            $client_details = NSMF::Server::AuthMngr->authenticate_client($client, $secret);
        };

        if ($@) {
            $logger->error('Client authentication unsupported: ', $@);
            $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_AUTH_UNSUPPORTED));
            return;
        }

        $heap->{name} = $client;

        $logger->debug("Client authenticated: $client");

        # generate the session ID
        $heap->{session_key} = 1;

        $heap->{client}->put(json_result_create($json, $client_details));

        # clients don't require an ident and are established
        $heap->{status} = 'EST';
    }
}

sub identify {
    my ($kernel, $session, $heap, $json) = @_[KERNEL, SESSION, HEAP, ARG0];
    my $self = shift;

    if ( $heap->{status} ne 'ID' ) {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_UNAUTHORIZED));
        return;
    }

    eval {
        json_validate($json, ['$module','$netgroup']);
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

        eval {
            $heap->{module} = NSMF::Server::ModMngr->load(uc($module_type));
        };

        if ($@) {
            $logger->error('Could not load module type: ' . $module_type);
            $logger->debug($@);
        }

        # generate the session key
        $heap->{session_key} = $_[SESSION]->ID;

        if (defined $heap->{module}) {
            $logger->debug("----> Module Call <----");

            $heap->{client}->put(json_result_create($json, $module_details));
            # $kernel->yield('has_pcap'); # DEBUG
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

    $logger->debug(' -> This is a post for ' . $heap->{name});

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
}

sub send_ping {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    $logger->debug('  -> Sending PING');
    my $payload = "PING " .time. " NSMF/1.0\r\n";
    $heap->{client}->put($payload);
}

sub get {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    if ( $heap->{status} ne 'EST' || ! $heap->{session_key}) {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_BAD_REQUEST));
        return;
    }

    eval {
       my ($ret, $response) = json_validate($json, ['$type', '$jobid', '%data']);
    };

    if ( ref $@ ) {
      $logger->error('Incomplete GET request. ' . $@->{message});
      $heap->{client}->put($@->{object});
      return;
    }

    # search data
    my $payload = encode_base64( compress( 'A'x1000 ) );
    $heap->{client}->put(json_result_create($json, $payload));
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
            $logger->debug(" -> SPAWNING LISTENER");

           NSMF::Server::Action->file_catcher({
              transfer_id => $json->{id},,
              checksum    => $json->{result}{checksum},
           });

        } else {
            $logger->debug("Error: Expected file metadata from node");
            $logger->debug(Dumper $json);
        }


    });
    
    $heap->{client}->put(json_encode($payload));

}

1;
