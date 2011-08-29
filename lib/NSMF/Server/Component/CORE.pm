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
package NSMF::Server::Component::CORE;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Server::Component);

#
# PERL INCLUDES
#
use Module::Pluggable require => 1;

#
# NSMF INCLUDES
#
use NSMF::Server;
use NSMF::Common::Logger;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

my $nsmf    = NSMF::Server->new();
my $config  = $nsmf->config;
my $modules =["core", @{ $config->modules() }];

my $commands_list = {
  "modules_available" => {
    "help" => "Returns the available modules.",
    "exec" => \&get_modules_available,
    "acl" => 0,
  },
  "register_node" => {
    "help" => "Register a node to the NSMF framework.",
    "exec" => sub{},
    "acl" => 128,
  },
  "unregister_node" => {
    "help" => "Unregister a node from the NSMF framework.",
    "exec" => sub{},
    "acl" => 128,
  },
  "register_client" => {
    "help" => "Register a client to the NSMF framework.",
    "exec" => sub{ },
    "acl" => 127,
  },
  "unregister_client" => {
    "help" => "Unregister a client from the NSMF framework.",
    "exec" => sub{ },
    "acl" => 127,
  },
  "subscribe_netgroup" => {
    "help" => "Subscribe to specified netgroup on the NSMF framework.",
    "exec" => sub{ },
    "acl" => 127,
  },
  "unsubscribe_netgroup" => {
    "help" => "Unsubscribe from a specified netgroup on the NSMF framework.",
    "exec" => sub{ },
    "acl" => 127,
  },
};

my @commands = keys %{ $commands_list };


sub init {
    my $self = shift;
    my $acl = shift;

    $logger->debug("OVERRIDE ACL: " . $acl);
    $self->{_get_commands} = [ grep { $commands_list->{$_}{acl} <= $acl } sort(keys(%{ $commands_list })) ];
    return $self;
}

sub hello {
    $logger->debug("Hello World from the CORE Module!");
    my $self = shift;
    $_->hello for $self->plugins;
}


sub post {
    my ($self) = @_;

    return 1;
}


#
# COMMAND
#
# syntax: [help_]command
#



sub get {
    my ($self, $data) = @_;

    $logger->debug($self, $data);

    my $command = undef;
    my $params = undef;

    if( ref($data->{data}) eq 'ARRAY' ) {
        $command = $data->{data}->[0];
        $params = splice(@{ $data->{data} }, 1);
    }
    else {
        $command = $data->{data};
    }

    given( $command ) {
        when( @commands ) {
            $logger->debug($command, $commands_list);

            return $commands_list->{$command}{exec}->($params);
        }
        when( /^help/ ) {
            # prefixed command with "help_"
            if ( length($command) > 5 ) {
                $command = substr($command, 5);

                if ( $command ~~ @commands ) {
                    return $self->get_format_help($commands_list->{$command}{help});
                }
            }

            return "Commands available: " . join(", ", @{ $self->{_get_commands} })
        }
        default {
            die {
                message => 'Unknown module command',
                code => -10000
            };
        }
    }

    return 0;
}

sub get_format_help
{
    my ($self, $help_markdown) = @_;

    return $help_markdown;
}

sub get_modules_available
{
    my ($self) = @_;

    return $modules;
}

1;
