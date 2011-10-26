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
use Data::Dumper;
use POE;
use POE::Filter::Line;
use POE::Component::Client::TCP;

#
# NSMF INCLUDES
#
use NSMF::Agent;
use NSMF::Agent::ConfigMngr;
use NSMF::Agent::ProtoMngr;

use NSMF::Common::Util;
use NSMF::Common::Logger;
use NSMF::Common::Registry;

#
# GLOBALS
#
# The logger is going to be initialized later using the name
# of the node for the logfile
my $logger; 

#
# CONSTANTS
#
our $VERSION = {
  major    => 0,
  minor    => 0,
  revision => 0,
  build    => 1,
};

# Constructor
sub new {
    my $class = shift;

    my $obj = bless {
        __config_path   => undef,
        __config        => undef, 
        __proto         => undef,
        __started       => time(),
        __version       => $VERSION,
        __data          => {},
        __handlers      => {
            _net        => undef,
            _db         => undef,
            _sessid     => undef,
            _log        => undef,
        },
        __client        => undef,
        __id            => -1,
        _commands_all     => {},
        _commands_allowed => [],
    }, $class;

    return $obj->init(@_);
}

sub init {
    my ($self) = @_;

    $self->command_get_add({
        "get_node_uptime" => {
          "exec" => \&get_node_uptime,
        },
        "get_node_version" => {
          "exec" => \&get_node_version,
        },
        "get_node_id" => {
          "exec" => \&get_node_id,
        },
    });

    $self->{_commands_allowed} = [ keys( %{ $self->{_commands_all} } ) ];

    return $self;
}

# Public Interface to load config as pair of names and values
sub load_config {
    my ($self, $path) = @_;

    my $component = lc($1) if ref $self =~ /::([\w]+)$/;

    # initializing the gobal logger
    $NSMF::Common::Logger::LOG_DIR = File::Spec->catdir($NSMF::Agent::BASE_PATH, 'logs');

    $self->{__config} = NSMF::Agent::ConfigMngr->load($path);
    $logger  = NSMF::Common::Logger->load($self->{__config}{config}{log});

    NSMF::Common::Registry->set( 'log'    => $logger); 
    NSMF::Common::Registry->set( 'config' => $self->{__config}{config});

    eval {
        $self->{__proto}  = NSMF::Agent::ProtoMngr->create($self->{__config}->protocol());
    };

    if ( $@ ) {
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

    $self->{__client} = POE::Component::Client::TCP->new(
        Alias         => 'node',
        RemoteAddress => $host,
        RemotePort    => $port,
        Filter        => "POE::Filter::Line",
        Connected => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            $logger->info("[+] Connected to server ($host:$port) ...");

            $heap->{nodename} = $config->name();
            $heap->{nodetype} = $self->type();
            $heap->{netgroup} = $config->netgroup();
            $heap->{secret}   = $config->secret();
            $heap->{agent}    = $config->agent();

            $kernel->yield('authenticate');
        },
        ConnectError => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            $logger->warn("Could not connect to server ($host:$port)... Attempting reconnect in " . $heap->{reconnect} . 's');

            # reconnect
            $kernel->delay('connect', $heap->{reconnect});
        },
        ServerInput => sub {
            my ($kernel, $response) = @_[KERNEL, ARG0];

            $kernel->yield(dispatcher => $response);
        },
        ServerError => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            $logger->warn('Lost connection to server... Attempting reconnect in ' . $heap->{reconnect} . 's');

            # reconnect
            $kernel->delay('connect', $heap->{reconnect});
        },
        InlineStates => {
            connected => sub {
                my ($kernel, $heap) = @_[KERNEL, HEAP];

                return $heap->{connected} // 0;
            }
        },
        ObjectStates => [
            $proto => $proto->states(),
            $self => [ 'run', 'get' ]
        ],
        Started => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];

            $heap->{reconnect} = 10;
        },
    );
}

sub run {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $self = shift;

    $logger->fatal('Base run call needs to be overridden.');
}

sub command_get_add
{
    my ( $self, $commands ) = @_;

    # ensure we have a command hash
    if ( ref($commands) ne 'HASH' ) {
        $logger->error('Command(s) not a HASH description.');
        return;
    }

    # add all contained keys
    foreach my $c ( keys ( %{ $commands } ) ) {
        if ( defined($self->{_commands_all}{$c} ) ) {
            $logger->warn('Ignoring duplicate command definition: ' . $c);
            continue;
        }

        my $command = $commands->{$c};

        # ensure sane defaults
        $command->{exec}  //= sub {};

        # add the command to the stack
        $self->{_commands_all}{$c} = $command;
    }
}

sub get {
    my ($kernel, $heap, $data) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    my $command = undef;
    my $params = undef;

    # TODO: apply some structure here
    if( ref($data) ne 'HASH' ) {
        $command = $data;
    }
    else {
      my @c = keys(%{ $data });
      $command = $c[0];
      $params = $data->{$command};
    }

    given( $command ) {
        when( $self->{_commands_allowed} ) {
            # we pass $self due to exec being an function pointer
            return $self->{_commands_all}{$command}{exec}->($self, $kernel, $heap, $params);
        }
        default {
            $logger->error($self->{_commands_available});
        }
    }

    return 0;
}

sub get_node_id {
    my ($self, $kernel, $heap, $data) = @_;

    return $heap->{node_id};
}

sub get_node_uptime {
    my ($self, $kernel, $heap, $data) = @_;

    return time() - $self->{__started};
}

sub get_node_version {
    my ($self, $kernel, $heap, $data) = @_;

    return $self->{__version};
}

sub logger {
    return $logger // croak "Logger module has not been initialized";
}

sub type {
    my ($self) = @_;
    $logger->fatal("Component type needs to be overridden.");
}

# Returns the actual session
sub session {
    my ($self) = @_;

    return if ( ref($self) ne __PACKAGE__ );
    return $self->{__handlers}{_sessid};
}

sub start {
    POE::Kernel->run();
}

1;
