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
use Carp;

#
# NSMF INCLUDES
#
use NSMF::Server;
use NSMF::Common::Registry;

#
# GLOBALS
#

my $nsmf    = NSMF::Server->instance();
my $config  = $nsmf->config;
my $modules =["core", @{ $config->modules() }];
my $logger = NSMF::Common::Registry->get('log') 
    // carp 'Got an empty config object from Registry';

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

        "register_agent" => {
          "help" => "Register an agent to the Echidna framework.",
          "exec" => \&agent_register,
          "acl" => 128,
        },
        "unregister_agent" => {
          "help" => "Unregister an agent, and all subordinate nodes, from the Echidna framework.",
          "exec" => \&agent_unregister,
          "acl" => 128,
        },
        "register_node" => {
          "help" => "Register a node to the Echidna framework.",
          "exec" => \&node_register,
          "acl" => 128,
        },
        "unregister_node" => {
          "help" => "Unregister a node from the Echidna framework.",
          "exec" => \&node_unregister,
          "acl" => 128,
        },
        "register_client" => {
          "help" => "Register a client to the Echidna framework.",
          "exec" => \&client_register,
          "acl" => 127,
        },
        "unregister_client" => {
          "help" => "Unregister a client from the Echidna framework.",
          "exec" => \&client_unregister,
          "acl" => 127,
        },
        "update_client" => {
          "help" => "Unregister a client from the Echidna framework.",
          "exec" => \&client_update,
          "acl" => 127,
        },

        "subscribe_agent" => {
          "help" => "Subscribe to an agent's, and all subordinate nodes', broadcasts.",
          "exec" => sub{ },
          "acl" => 127,
        },
        "unsubscribe_agent" => {
          "help" => "Unsubscribe from an agent's, and all subordinate nodes', broadcasts.",
          "exec" => sub{ },
          "acl" => 127,
        },
        "subscribe_node" => {
          "help" => "Subscribe to a node's broadcasts.",
          "exec" => sub{ },
          "acl" => 127,
        },
        "unsubscribe_node" => {
          "help" => "Unsubscribe from a node's broadcasts.",
          "exec" => sub{ },
          "acl" => 127,
        },

        "server_version" => {
          "help" => "Returns the Version and revision of the Echidna server.",
          "exec" => \&get_server_version,
          "acl" => 127,
        },
        "server_uptime" => {
          "help" => "Returns the current uptime, in seconds, of the Echidna server.",
          "exec" => \&get_server_uptime,
          "acl" => 127,
        },


        "nodes_connected" => {
            "help" => "Return all nodes connected.",
            "exec" => \&get_nodes_connected,
            "acl" => 127,
        },
        "node_info" => {
            "help" => "Return node info.",
            "exec" => \&get_node_info,
            "acl" => 127,
        },

        "clients_connected" => {
            "help" => "Return all clients connected.",
            "exec" => \&get_clients_connected,
            "acl" => 127,
        },
        "client_info" => {
            "help" => "Return client info.",
            "exec" => \&get_client_info,
            "acl" => 127,
        },




        "search_agent" => {
            "help" => "Search for agents.",
            "exec" => \&get_event_details,
            "acl" => 255,
        },
        "search_node" => {
            "help" => "Search for nodes.",
            "exec" => \&get_event_details,
            "acl" => 255,
        },
        "search_client" => {
            "help" => "Search for clients.",
            "exec" => \&get_event_details,
            "acl" => 255,
        },
        "search_event" => {
            "help" => "Search for events.",
            "exec" => \&get_event_details,
            "acl" => 0,
        },
        "search_session" => {
            "help" => "Search for sessions.",
            "exec" => \&get_session_details,
            "acl" => 0,
        },
        "search_data" => {
            "help" => "Search for full-content data.",
            "exec" => \&get_data_details,
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
# CORE REGISTRATION
#

sub agent_register {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->insert({
        agent => $params
    });

    return $ret;
}

sub agent_unregister {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    if ( ! defined_args($params->{id}) ) {
        return 1;
    }

    # remove the agent and subordinate nodes
    my $ret = $db->delete({
        agent => {
            id => $params->{id}
        }
    });

    return $ret;
}

sub node_register {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->insert({
        node => $params
    });

    return $ret;
}

sub node_unregister {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    # remove the node
    my $ret = $db->delete({
        node => {
            id => $params->{id}
        }
    });

    return $ret;
}

sub client_register {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->insert({
        client => $params
    });

    return $ret;
}

sub client_unregister {
    my ($self, $params) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->delete({
        client => {
            id => $params->{id}
        }
    });

    return $ret;
}

sub client_update {
    my ($self, $params) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->update({
        client => $params
    },
    {
        id => $params->{id}
    });

    return $ret;
}


#
# CORE SUBSCRIPTION
#

sub agent_subscribe {
    my ($self, $params) = @_;

}

sub agent_unsubscribe {
    my ($self, $params) = @_;

}

sub node_subscribe {
    my ($self, $params) = @_;

}

sub node_unsubscribe {
    my ($self, $params) = @_;

}


#
# CORE GENERAL REQUESTS
#

sub get_server_version {
    my ($self, $params) = @_;

    my $version = $nsmf->{__version};

    return $version;
}

sub get_server_uptime {
    my ($self, $params) = @_;

    my $uptime = time() - $nsmf->{__started};

    return $uptime;;
}

sub get_server_queue {
    my ($self, $params) = @_;

}

sub get_server_status {
    my ($self, $params) = @_;

}


sub get_node_version {
    my ($self, $params) = @_;
    return 'ALPHA';
}

sub get_node_uptime {
    my ($self, $params) = @_;

}

sub get_node_queue {
    my ($self, $params) = @_;

}

sub get_node_status {
    my ($self, $params) = @_;

}


sub get_plugins_loaded {
    my ($self, $params) = @_;

}

sub get_plugin_info {
    my ($self, $params) = @_;

}


sub get_clients_connected {
    my ($self, $params) = @_;

    my $clients = $nsmf->clients();

    return $clients;
}

sub get_client_info {
    my ($self, $params) = @_;

}


sub get_nodes_connected {
    my ($self, $params) = @_;

    my $nodes = $nsmf->nodes();

    return $nodes;
}

sub get_node_info {
    my ($self, $params) = @_;

}



#
# CORE STRUCTURE SEARCHES
#

sub get_agent_details {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        agent => $params
    });

    return $ret;
}

sub get_node_details {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        agent => $params
    });

    return $ret;
}

sub get_client_details {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        agent => $params
    });

    return $ret;
}

sub get_event_details {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        event => $params
    });

    return $ret;
}

sub get_session_details {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        session => $params
    });

    return $ret;
}

sub get_data_details {
    my ($self, $params) = @_;

    my $db = NSMF::Server->database();

    $logger->debug($params);

    # TODO validate, process the params and return the result

    return "TODO: implement me";
}

1;
