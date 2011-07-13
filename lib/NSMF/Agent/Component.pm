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
package NSMF::Agent::Component;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Carp;
use Compress::Zlib;
use Data::Dumper;
use MIME::Base64;
use POE;
use POE::Filter::Line;
use POE::Component::Client::TCP;

#
# NSMF INCLUDES
#
use NSMF::Agent;
use NSMF::Agent::ConfigMngr;
use NSMF::Agent::ProtoMngr;
use NSMF::Common::Logger;
use NSMF::Common::Util;

#
# GLOBALS
#
our ($poe_kernel, $poe_heap);
my $logger = NSMF::Common::Logger->new();

# Constructor
sub new {
    my $class = shift;

    bless {
        __config_path   => undef,
        __config        => NSMF::Agent::ConfigMngr->instance(),
        __proto         => undef,
        __data          => {},
        __handlers      => {
            _net        => undef,
            _db         => undef,
            _sessid     => undef,
        },
        __main          => \&run,
    }, $class;
}

# Public Interface to load config as pair of names and values
sub load_config {
    my ($self, $path) = @_;

    $self->{__config}->load($path);

    eval {
        $self->{__proto} = NSMF::Agent::ProtoMngr->create($self->{__config}->protocol());
    };

    if ( $@ )
    {
        $logger->fatal($@);
    }

    return $self->{__config};
}

# Returns actual configuration settings
sub config {
    my ($self) = @_;

    return if ( ref($self) ne __PACKAGE__ );

    return $self->{__config} // die { status => 'error', message => 'No configuration file loaded.' }; 
}

sub sync {
    my ($self) = @_;

    my $config = $self->{__config};
    my $proto = $self->{__proto};

    my $host = $config->host();
    my $port = $config->port();

    return if ( ! defined_args($host, $port) );

    POE::Component::Client::TCP->new(
        Alias         => 'node',
        RemoteAddress => $host,
        RemotePort    => $port,
        Filter        => "POE::Filter::Line",
        Connected => sub {
            $logger->info("[+] Connected to server ($host:$port) ...");

            $_[HEAP]->{nodename} = $config->name();
            $_[HEAP]->{netgroup} = $config->netgroup();
            $_[HEAP]->{secret}   = $config->secret();
            $_[HEAP]->{agent}    = $config->agent();

            $_[KERNEL]->yield('authenticate');
        },
        ConnectError => sub {
            $logger->warn("Could not connect to server ($host:$port) ...");
        },
        ServerInput => sub {
            my ($kernel, $response) = @_[KERNEL, ARG0];

            $kernel->yield(dispatcher => $response);
        },
        ServerError => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            $logger->warn("Lost connection to server...");
            $logger->info("Going Down.");
            exit;
        },
        ObjectStates => [
            $proto => $proto->states(),
            $self => [ 'run' ]
        ],
    );
}

sub run {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $self = shift;

    $logger->fatal('Base run call needs to be overridden.');
}

sub register {
    my ($self, $kernel, $heap) = @_;
    $poe_kernel = $kernel;
    $poe_heap   = $heap;
}

# Send Data function
# Requires $poe_heap to be defined with the POE HEAP
# Must be used only after run() method has been executed.
sub put {
    my ($self, $data) = @_;

    return unless ref $poe_heap;

    $poe_heap->{server}->put($data);
}

sub ping {
    my ($self) = @_;
    return unless ref $poe_heap;

    my $payload = 'PING ' .time(). ' NSMF/1.0' ."\r\n";
    $poe_heap->{server}->put($payload);
}

# Returns the actual session
sub session {
    my ($self) = @_;

    return if ( ref($self) ne __PACKAGE__ );
    return $self->{__handlers}{_sessid};
}

sub start {
    POE::Kernel->run;
}

1;
