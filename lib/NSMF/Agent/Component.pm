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
package NSMF::Agent::Component;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Carp;
use Data::Dumper;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;


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
        __exit          => AnyEvent->condvar(),

        __config_path   => undef,
        __config        => undef,
        __proto         => undef,

        __started       => time(),      # time node started
        __version       => $VERSION,    # version of node

        __agent_id      => -1,          # agent id
        __node_id       => -1,          # node id
        __session_id    => -1,          # id of the active session
        __connected     => 0,

        __data          => {},

        __client        => undef,

        _commands_all     => {},
        _commands_allowed => [],
    }, $class;

    return $obj->init(@_);
}

sub init {
    my ($self) = @_;

    $self->command_get_add({
        get_node_uptime => {
          exec => \&get_node_uptime,
        },
        get_node_id => {
          exec => \&get_node_id,
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
        $self->{__proto} = NSMF::Agent::ProtoMngr->create($self->{__config}->protocol());
        $self->{__proto}->set_parent($self);
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

    $self->server_connect();
}

sub server_connect {
    my ($self) = @_;

    my $config = $self->{__config};
    my $proto = $self->{__proto};

    my $host = $config->host();
    my $port = $config->port();

    return if ( ! defined_args($host, $port) );

    $self->{__handle} = AnyEvent::Handle->new(
      connect           => [$host, $port],
      on_connect        => sub { $self->server_on_connect(@_); },
      on_connect_error  => sub { $self->server_connect_error(@_); },
      on_error          => sub { $self->server_error(@_); },
      on_read           => sub { $self->server_read(@_); },
      on_eof            => sub { $self->server_closed(@_); },
    );
}

sub server_on_connect {
    my ($self, $handle, $host, $port) = @_;

    $self->{__proto}->set_handle($handle);

    $logger->info('[+] Connected to server (' . $host . ':' . $port. ')...');

    my $config = $self->{__config};

    $self->{nodename} = $config->name();
    $self->{nodetype} = $self->type();
    $self->{netgroup} = $config->netgroup();
    $self->{secret}   = $config->secret();
    $self->{agent}    = $config->agent();

    $self->{__proto}->authenticate();

    $self->{__connected} = 1;
}

sub server_connect_error {
    my ($self, $handle, $message) = @_;

    $logger->warn('Could not connect to server (' .
        $self->{__config}->host() . ':' .
        $self->{__config}->port() . ')');
    $self->server_reconnect();
}

sub server_error {
    my ($self, $handle, $fatal, $message) = @_;

    $logger->error('Connection error: ' . $message);

    $self->{__connected} = 0;

    $self->server_reconnect();
}

sub server_reconnect {
    my ($self) = @_;

    # initiate a reconnection
    my $reconnect = $self->{reconnect} // 60;

    $logger->info('Attempting reconnect in ' . $reconnect . 's');

    # only set the reconnect timer once
    return if ( defined($self->{_reconnect}) );

    $self->{_reconnect} = AnyEvent->timer(
        after => $reconnect,
        cb => sub {
            $self->server_connect();

            # clear up our variable
            undef( $self->{_reconnect} );
        }
    );
}

sub server_read {
    my ($self, $handle) = @_;

    $self->{__proto}->read();
}

sub server_closed {
    my ($self, $handle, $fatal, $message) = @_;

    $self->{__connected} = 0;

    # TODO: initiate a shutdown
}

sub connected {
    my ($self) = @_;

    return $self->{__connected} == 1;
}

sub run {
    my ($self) = @_;

    $logger->fatal('Base run call needs to be overridden.');
}

sub command_get_add
{
    my ($self, $commands) = @_;

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
    my ($self, $data) = @_;

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
            return $self->{_commands_all}{$command}{exec}->($self, $params);
        }
        default {
            $logger->error($self->{_commands_available});
        }
    }

    return 0;
}

sub get_node_id {
    my ($self) = @_;
    return $self->{__node_id};
}

sub get_node_uptime {
    my ($self) = @_;

    return time() - $self->{__started};
}

sub get_node_version {
    my ($self) = @_;

    return $self->{__version};
}

# identify
sub set_identity {
    my ($self, $identity) = @_;

    return if ( ! ref($identity) eq 'HASH' );

    $logger->debug('Setting Identity');

    if( defined($identity->{node_id}) ) {
        $self->{__node_id} = $identity->{node_id};
    }

    if( defined($identity->{agent_id}) ) {
        $self->{__agent_id} = $identity->{agent_id};
    }
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
    return $self->{__session_id};
}

sub start {
    my ($self) =@_;

    # start event loop, waiting for our exit condition
    $self->{__exit}->recv();
}

1;
