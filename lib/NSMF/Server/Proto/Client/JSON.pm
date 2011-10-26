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
package NSMF::Server::Proto::Client::JSON;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Compress::Zlib;
use Data::Dumper;
use Date::Format;
use Carp;
use POE qw(
    Session
    Wheel::Run
    Filter::Reference
);

#
# NSMF INCLUDES
#
use NSMF::Common::JSON;
use NSMF::Common::Util;
use NSMF::Common::Registry;

use NSMF::Server;
use NSMF::Server::AuthMngr;
use NSMF::Server::ModMngr;

#
# GLOBALS
#
my $instance;
my $logger = NSMF::Common::Registry->get('log')
    // carp 'Got an empty config object from Registry';

my $config = NSMF::Common::Registry->get('config')
    // carp 'Got an empty config object from Registry';

my $modules = $config->modules() // [];

#
# CLIENT/NODE tracking
#
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
        'ping',
        'post',
        'get',

        'client_registered',
        'client_unregistered',

        'client_broadcast'
    ];
}

sub client_registered {
    my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];

    my $clients = NSMF::Server->instance()->clients();

    $clients->{$session->ID()} = {
        id => $heap->{details}{id},
        name => $heap->{details}{name},
        description => $heap->{details}{description} // '',
    };

    # update DB
}

sub client_unregistered {
    my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];

    my $clients = NSMF::Server->instance()->clients();

    delete $clients->{$session->ID()};
}

sub client_broadcast {
    my ($kernel, $session, $heap, $module, $args) = @_[KERNEL, SESSION, HEAP, ARG0, ARG1];

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
        $logger->debug('Client authentication request unsupported: ', $@);
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_AUTH_UNSUPPORTED));
        return;
    }

    $heap->{name} = $client;
    $heap->{acl} = $client_details->{level};
    $heap->{details} = $client_details;
    $heap->{module} = {};

    $logger->debug("Client authenticated: $client");

    # generate the session ID
    $heap->{session_key} = 1;

    $kernel->yield('client_registered');

    $heap->{client}->put(json_result_create($json, $client_details));

    # clients don't require an ident and are established
    $heap->{status} = 'EST';
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

    $logger->debug('This is a POST for ' . $heap->{name});

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

sub get {
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
      $logger->error('Incomplete GET request. ' . $@->{message});
      $heap->{client}->put($@->{object});
      return;
    }

    my $module_type = $json->{params}{type};

    $logger->debug('This is a GET for ' . $module_type);

    my $modules_allowed = ["core", @{ $modules }];

    if ( $module_type ~~ @{ $modules_allowed } ) {
        # dyamically load module as required
        if ( ! defined($heap->{module}{$module_type}) ) {
            $logger->debug("-> " .uc($module_type). " supported!");

            eval {
                $heap->{module}{$module_type} = NSMF::Server::ModMngr->load(uc($module_type), $heap->{acl});
            };

            if ($@) {
                $logger->error('Could not load module type: ' . $module_type);
                $logger->debug($@);
                $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_GET_UNSUPPORTED));
                return;
            }
        }

        if ( defined($heap->{module}{$module_type}) ) {
            $logger->debug("Module Called");

            my $ret = undef;

            eval {
                $ret = $heap->{module}{$module_type}->get( $json->{params}{data}, sub { 
                    my $ret = shift;
                    my $response = json_result_create($json, $ret);

                    # don't reply with empty strings
                    if ( $response ne '' ) {
                        $heap->{client}->put($response);
                    }
                });
            };

            if ( $@ ) {
                $logger->error($@);
                my $response = json_error_create($json, {
                    message => $@->{message},
                    code => $@->{code}
                });

                # don't reply with empty strings
                if ( $response ne '' ) {
                    $heap->{client}->put($response);
                }
            }
        }
    }
    # module is not supported
    else {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_GET_UNSUPPORTED));
    }
}

sub _is_authenticated {
    my $heap = shift;
    return 1 unless ( $heap->{status} ne 'EST' || ! $heap->{session_key});
}

1;
