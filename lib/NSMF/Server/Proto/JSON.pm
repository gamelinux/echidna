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
        'got_ping',
        'got_pong',
        'got_post',
        'send_ping',
        'send_pong',
        'send_error',
        'get',
        'child_output',
        'child_error',
        'child_signal',
        'child_close',
    ];
}

sub dispatcher {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    my $json = {};

    eval {
        $json = json_decode(trim($request));
    };

    if ( $@ ) {
        $logger->error('Invalid JSON request' . $request);
        return;
    }

    if ( exists($json->{method}) )
    {
        my $action = $json->{method};

        given($json->{method}) {
            when(/authenticate/) { }
            when(/identify/) { }
            when(/ping/) {
                $action = 'got_ping';
            }
            when(/pong/) {
                $action = 'got_pong';
            }
            when(/post/i) {
                $action = 'got_post';
            }
            when(/get/i) {
                $action = 'get';
            }
            default: {
                $logger->debug(Dumper($json));
                $action = 'send_error';
            }
        }

        $kernel->yield($action, $json);
    }
}

sub authenticate {
    my ($kernel, $session, $heap, $json) = @_[KERNEL, SESSION, HEAP, ARG0];
    my $self = shift;

    $logger->debug( "  -> Authentication Request");

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

    eval {
        NSMF::Server::AuthMngr->authenticate($agent, $secret);
    };

    if ($@) {
        $logger->error('    = Not Found ', $@);
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_AUTH_UNSUPPORTED));
        return;
    }

    $heap->{agent}    = $agent;
    $logger->debug("    [+] Agent authenticated: $agent"); 

    $heap->{client}->put(json_result_create($json, ''));
}

sub identify {
    my ($kernel, $session, $heap, $json) = @_[KERNEL, SESSION, HEAP, ARG0];
    my $self = shift;

    eval {
        json_validate($json, ['$module','$netgroup']);
    };

    if ( ref $@ ) {
      $logger->error('Incomplete JSON ID request. ' . $@->{message});
      $heap->{client}->put($@->{object});
      return;
    }

    my $module = trim(lc($json->{params}{module}));
    my $netgroup = trim(lc($json->{params}{netgroup}));

    if ($heap->{session_id}) {
        $logger->warn( "$module is already authenticated");
        return;
    }

    if ($module ~~ @$modules) {

        $logger->debug("    ->  " .uc($module). " supported!"); 

        $heap->{module_name} = $module;
        $heap->{session_id} = 1;
        $heap->{status}     = 'EST';

        eval {
            $heap->{module} = NSMF::Server::ModMngr->load(uc $module);
        };

        if ($@) {
            $logger->error("    [FAILED] Could not load module: $module");
            $logger->debug($@);
        }

        $heap->{session_id} = $_[SESSION]->ID;

        if (defined $heap->{module}) {
            # $logger->debug("Session Id: " .$heap->{session_id});
            # $logger->debug("Calilng Hello World Again in the already defined module");
            $logger->debug("      ----> Module Call <----");
            $heap->{client}->put(json_result_create($json, 'ID accepted'));
            return;
            my $child = POE::Wheel::Run->new(
                Program => sub { $heap->{module}->run  },
                StdoutFilter => POE::Filter::Reference->new(),
                StdoutEvent => "child_output",
                StderrEvent => "child_error",
                CloseEvent  => "child_close",
            );

            $kernel->sig_child($child->PID, "child_signal");
            $heap->{children_by_wid}{$child->ID} = $child;
            $heap->{children_by_pid}{$child->PID} = $child;
        }
    }
    else {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_IDENT_UNSUPPORTED));
    }

}

sub got_pong {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    $logger->debug("  <- Got PONG"); 
}

sub got_ping {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

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

    if ( $heap->{status} ne 'EST' || ! $heap->{session_id}) {
        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_UNAUTHORIZED));
        return;
    }

    $logger->debug("  <- Got PING");
    $kernel->yield('send_pong', $json);
}

sub child_output {
    my ($kernel, $heap, $output) = @_[KERNEL, HEAP, ARG0];
    $logger->debug(Dumper($output));
}

sub child_error {
    $logger->error("Child Error: $_[ARG0]");
}

sub child_signal {
    my $heap = $_[HEAP];
    #$logger->debug("   * PID: $_[ARG1] exited with status $_[ARG2]");
    my $child = delete $heap->{children_by_pid}{$_[ARG1]};

    return if ( ! defined($child) );

    delete $heap->{children_by_wid}{$child->ID};
}

sub child_close {
    my ($heap, $wid) = @_[HEAP, ARG0];
    my $child = delete $heap->{children_by_wid}{$wid};

    if ( ! defined($child) ) {
    #    $logger->debug("Wheel Id: $wid closed");
        return;
    }

    #$logger->debug("   * PID: " .$child->PID. " closed");
    delete $heap->{children_by_pid}{$child->PID};
}

sub got_post {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    if ( $heap->{status} ne 'EST' || ! $heap->{session_id}) {
        $heap->{client}->put(json_result_create($json, 'Bad request'));
        return;
    }

    eval {
        my ($ret, $response) = json_validate($json, ['$type', '$jobid', '%data']);
    };

    if ( ref $@ ) {
      $logger->error('Incomplete POST request. ' . $@->{message});
      $heap->{client}->put($@->{object});
      return;
    }

    $logger->debug(' -> This is a post for ' . $heap->{module_name});
#    $logger->debug('    - Type: '. $json->{params}{type});
#    $logger->debug('    - Job Id: ' . $json->{params}{job_id});

    my $module = $heap->{module};

    eval {
        $module->save( $json->{params} );
    };

    if ( $@ ) {
        $logger->error($@);
    }
    else
    {
        $logger->debug("    Session saved");

        # need to reply here
    }
}

sub send_ping {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    $logger->debug('  -> Sending PING');
    my $payload = "PING " .time. " NSMF/1.0\r\n";
    $heap->{client}->put($payload);
}

sub send_pong {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    $logger->debug('  -> Sending PONG');

    my $response = json_result_create($json, {
        "timestamp" => time()
    });

    $heap->{client}->put($response);
}

sub send_error {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    warn "[!] BAD REQUEST" if $NSMF::Server::DEBUG;
    $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_BAD_REQUEST));
}

sub get {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    if ( $heap->{status} ne 'EST' || ! $heap->{session_id}) {
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

1;
