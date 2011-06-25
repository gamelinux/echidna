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
package NSMF::Server::Proto::HTTP;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Data::Dumper;
use Date::Format;
use Compress::Zlib;
use MIME::Base64;
use POE;
use POE::Session;
use POE::Filter::Reference;
use POE::Wheel::Run;

#
# NSMF INCLUDES
#
use NSMF::Server;
use NSMF::Util;
use NSMF::Common::Logger;
use NSMF::Server::ModMngr;
use NSMF::Server::AuthMngr;
use NSMF::Server::ConfigMngr;

#
# GLOBALS
#
our $VERSION = '0.1';

my $instance;
my $config = NSMF::Server::ConfigMngr->instance;
my $logger = NSMF::Common::Logger->new();
my $modules = $config->{modules} // [];

my $ACCEPTED = 'NSMF/1.0 200 OK ACCEPTED';

sub instance {
    unless ($instance) {
        my ($class) = @_;
        return bless({}, $class);
    }

    return $instance;
}

sub states {
    my ($self) = @_;

    return unless ref($self) eq 'NSMF::Server::Proto::HTTP';

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
    my ($kernel, $request) = @_[KERNEL, ARG0];

    my $AUTH_REQUEST = '^AUTH (\w+) (\w+) NSMF\/1.0$';
    my $ID_REQUEST   = '^ID (\w)+ NSMF\/1.0$';
    my $PING_REQUEST = 'PING (\d)+ NSMF/1.0';
    my $PONG_REQUEST = 'PONG (\d)+ NSMF/1.0';
    my $POST_REQUEST = '^POST (\w)+ (\d)+ NSMF\/1.0'."\n\n".'(\w)+';
    my $GET_REQUEST  = '^GET (\w)+ NSMF\/1.0$';

    my $action;

    given($request) {
        when(/$AUTH_REQUEST/i) { $action = 'authenticate' }
        when(/$ID_REQUEST/i)   { $action = 'identify' }
        when(/^$PING_REQUEST/i) { $action = 'got_ping' }
        when(/^$PONG_REQUEST/i) { $action = 'got_pong' }
        when(/$POST_REQUEST/i) { $action = 'got_post' }
        when(/$GET_REQUEST/i)  { $action = 'get' }
        default: {
            $logger->debug(Dumper($request));
            $action = 'send_error';
        }
    }
    $kernel->yield($action, $request);
}

sub authenticate {
    my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
    $input = trim($input);

    $logger->debug('  -> Authentication Request: ' . $input) 

    my $parsed = parse_request(auth => $input);
    if ( ref($parsed) ne 'AUTH') {
        $logger->debug('authhh');
        $heap->put('NSMF/1.0 400 BAD REQUEST');
        return;
    }

    my $agent    = lc $parsed->{agent};
    my $key      = lc $parsed->{key};

    eval {
        NSMF::Server::AuthMngr->authenticate($agent, $key);
    };

    if ($@) {
        $logger->debug('    = Not Found ' . $@ );
        $heap->{client}->put("NSMF/1.0 402 UNSUPPORTED\r\n");
        return;
    }

    $heap->{agent}    = $agent;
    $logger->debug("    [+] Agent authenticated: $agent");
    $heap->{client}->put("NSMF/1.0 200 OK ACCEPTED\r\n");
}

sub identify {
    my ($kernel, $session, $heap, $request) = @_[KERNEL, SESSION, HEAP, ARG0];

    my @data   = split /\s+/, trim($request);
    my $module = trim lc $data[1];
    my $netgroup = trim lc $data[2];


    if ($heap->{session_id}) {
        $logger->debug("$module is already authenticated");
        return;
    }

    if ($module ~~ @$modules) {

        $logger->debug('    ->  ' .uc($module). ' supported!');

        $heap->{module_name} = $module;
        $heap->{session_id} = 1;
        $heap->{status}     = 'EST';

        eval {
            $heap->{module} = NSMF::Server::ModMngr->load(uc $module);
        };

        if ($@) {
            $logger->debug('    [FAILED] Could not load module: $module');
            $logger->debug($@); 
        }
   
        $heap->{session_id} = $_[SESSION]->ID;

        if (defined $heap->{module}) {
            # $logger->debug( "Session Id: " .$heap->{session_id};
            # $logger->debug( "Calilng Hello World Again in the already defined module";
            $logger->debug('      ----> Module Call <----'); 
            $heap->{client}->put("NSMF/1.0 200 OK ACCEPTED\r\n");
            return;
            my $child = POE::Wheel::Run->new(
                Program => sub { $heap->{module}->run  },
                StdoutFilter => POE::Filter::Reference->new(),
                StdoutEvent => "child_output",
                StderrEvent => "child_error",
                CloseEvent  => "child_close",
            );

            $_[KERNEL]->sig_child($child->PID, "child_signal");
            $_[HEAP]{children_by_wid}{$child->ID} = $child;
            $_[HEAP]{children_by_pid}{$child->PID} = $child;
        }
    } 
    else {
        $heap->{client}->put("NSMF/1.0 401 UNSUPPORTED\r\n");
    }

}

sub got_pong {
    my ($kernel, $heap, $input) = @_[KERNEL, HEAP, ARG0];

    $logger->debug('  <- Got PONG');
}

sub got_ping {
    my ($kernel, $heap, $input) = @_[KERNEL, HEAP, ARG0];

    my @params    = split /\s+/, trim($input);
    my $ping_time = $params[1]; 

    $heap->{ping_recv} = $ping_time if $ping_time;

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $heap->{client}->put("NSMF/1.0 401 UNAUTHORIZED\r\n");
        return;
    }

    $logger->debug('  <- Got PING');
    $kernel->yield('send_pong');
}

sub child_output {
    my ($kernel, $heap, $output) = @_[KERNEL, HEAP, ARG0];
    $logger->debug(Dumper($output));
}

sub child_error {
    $logger->debug('Child Error: ' . $_[ARG0]);
}

sub child_signal {
    #$logger->debug("   * PID: $_[ARG1] exited with status $_[ARG2]");
    my $child = delete $_[HEAP]{children_by_pid}{$_[ARG1]};

    return unless defined $child;

    delete $_[HEAP]{children_by_wid}{$child->ID};
}

sub child_close {
    my $wid = $_[ARG0];
    my $child = delete $_[HEAP]{children_by_wid}{$wid};

    unless (defined $child) {
    #    $logger->debug( "Wheel Id: $wid closed");
        return;
    }

    #$logger->debug("   * PID: " .$child->PID. " closed");
    delete $_[HEAP]{children_by_pid}{$child->PID};
}

sub got_post {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    if ($heap->{status} ne 'EST' or ! defined(heap->{session_id})) {
        $heap->{client}->put("NSMF/1.0 400 BAD REQUEST\r\n");
        return;
    }

    my $parsed = parse_request(post => $request);

    return if ( ref($parsed) ne 'POST' );

    $logger->debug(' -> This is a post for ' . $heap->{module_name});
    $logger->debug('    - Type: '. $parsed->{type});
    $logger->debug('    - Job Id: ' .$parsed->{job_id});

    my $append;
    my $data = $parsed->{data};
    for my $line (@{ $parsed->{data} }) {
        $append .= $line;
    }

    my @sessions = split /\n/, decode_base64 $append;
    
    my $module = $heap->{module};
    for my $session ( @sessions ) {
        next unless $module->validate( $session );

        $module->save( $session ) or $logger->error($module->errstr);
        $logger->debug('    Session saved');
    }
    
}   

sub send_ping {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    $logger->debug('  -> Sending PING');
    my $payload = "PING " .time. " NSMF/1.0\r\n";
    $heap->{client}->put($payload);
}

sub send_pong {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    $logger->debug( '  -> Sending PONG';
    my $payload = "PONG " .time. " NSMF/1.0\r\n";
    $heap->{client}->put($payload);
}

sub send_error {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $client = $heap->{client};

    $logger->warn('[!] BAD REQUEST');
    $logger->debug('Sending BAD error');

    $client->put("NSMF/1.0 400 BAD REQUEST\r\n");
}

sub get {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $logger->debug('Sending BAD GET');
        $heap->{client}->put("NSMF/1.0 400 BAD REQUEST\r\n");
        return;
    }

    my $req = parse_request(get => $request);
    unless (ref $req) { 
    $logger->debug('BAD in GET');
        $heap->{client}->put('NSMF/1.0 400 BAD REQUEST');
        return;
    }

    # search data
    my $payload = encode_base64( compress( 'A'x1000 ) );
    $heap->{client}->put('POST ANumbers NSMF/1.0' ."\r\n". $payload);
    
}

sub parse_request {
    my ($type, $input) = @_;

    if (ref $type) {
        my %hash = %$type;
        $type = keys %hash;
        $input = $hash{$type};
    }
    my @types = qw(
        auth id get post
    );
   
    return unless grep $type, @types;
    return unless defined $input;

    my @request = split '\s+', $input;
    given($type) {
        when(/auth/i) { 
            return bless { 
                method   => $request[0],
                agent    => $request[1],
                key       => $request[2],
                tail     => $request[3],
            }, 'AUTH';
        }
        when(/id/i) {
            return bless {
                method => $request[0] // undef,
                node   => $request[1] // undef,
            }, 'ID';
        }
        when(/get/i) {
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                query  => $request[4] // undef,
            }, 'GET';
        }
        when(/post/i) {

            my @data;
            push @data, $request[$_] for (4..$#request);
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                data   => \@data // undef,
            }, 'POST';
        }
    }
}


1;
