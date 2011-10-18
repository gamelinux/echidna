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

#
# MEMBERS
#

sub init {
    my ($self, $acl) = @_;

    # init the base class first
    $self->SUPER::init($acl);

    $self->command_get_add({
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

        "search_event" => {
            "help" => "Search for events.",
            "exec" => \&search_event,
            "acl" => 0,
        },
        "search_session" => {
            "help" => "Search for sessions.",
            "exec" => \&search_session,
            "acl" => 0,
        },
        "search_data" => {
            "help" => "Search for full-content data.",
            "exec" => \&search_data,
            "acl" => 0,
        },
    });

    $self->{_commands_allowed} = [ grep { $self->{_commands_all}{$_}{acl} <= $acl } sort( keys( %{ $self->{_commands_all} } ) ) ];

    return $self;
}

sub hello {
    $logger->debug("Hello World from the CORE Module!");
    my $self = shift;
    $_->hello for $self->plugins;
}





#
# COMMAND
#
# syntax: [help_]command
#




sub get_modules_available
{
    my ($self) = @_;

    return $modules;
}




#
# CORE STRUCTURE SEARCHES
#

sub search_event {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        event => $params
    });

    return $ret;
}

sub search_session {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        session => $params
    });

    return $ret;
}

sub search_data {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    $logger->debug($params);

    # TODO validate, process the params and return the result

    return "TODO: implement me";
}

1;
