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
package NSMF::Server::Component;

use warnings;
use strict;
use v5.10;

use base qw(Exporter);

#
# NSMF INCLUDES
#
use NSMF::Common::Logger;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

#
# MEMBERS
#

sub new {
    my $class = shift;

    my $obj = bless {
        _acl              => 0,
        _commands_all     => {},
        _commands_allowed => [],
    }, $class;

    return $obj->init(@_);
}

sub init {
    my ($self, $acl) = @_;

    $self->{_acl} = $acl // 0;

    $self->command_get_add({
        "commands_available" => {
          "help" => "List all available commands for this module.",
          "exec" => \&get_commands_available,
          "acl" => 0,
        },
    });

    $self->{_commands_allowed} = [ grep { $self->{_commands_all}{$_}{acl} <= $acl } sort( keys( %{ $self->{_commands_all} } ) ) ];

    return $self;
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
        $command->{help}  //= 'TODO: write help description';
        $command->{acl}   //= 127;
        $command->{exec}  //= sub {};

        # add the command to the stack
        $self->{_commands_all}{$c} = $command;
    }
}


#
# POST
# TODO: RENAME process
#
sub process {
    my ($self) = @_;

    $logger->warn('Base PROCESS needs to be overridden.');

    return 1;
}

#
# GET
#
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
        when( /^help/ ) {
            # prefixed command with "help_"
            if ( length($command) > 5 ) {
                $command = substr($command, 5);

                if ( $command ~~ $self->{_commands_allowed} ) {
                    return $self->get_format_help($self->{_commands_all}{$command}{help});
                }
            }

            return "Commands available: " . join(", ", @{ $self->get_commands_available() })
        }
        default {
            $logger->debug($self->{_commands_available});
            die {
                message => 'Unknown module command: ' . $command,
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



sub get_commands_available
{
    my ($self) = @_;

    return $self->{_commands_allowed};
}

1;
