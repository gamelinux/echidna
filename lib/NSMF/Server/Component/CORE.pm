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
use Carp;
use Module::Pluggable require => 1;
use POE;

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
          # returns the available modules
          "exec" => \&get_modules_available,
          "acl" => 0,
        },

        "register_agent" => {
          # register an agent to the Echidna framework
          "exec" => \&agent_register,
          "acl" => 128,
        },
        "unregister_agent" => {
          # unregister an agent, and all subordinate nodes, from the Echidna framework
          "exec" => \&agent_unregister,
          "acl" => 128,
        },
        "update_agent" => {
          # update an agent's details on the Echidna framework
          "exec" => \&agent_update,
          "acl" => 128,
        },
        "register_node" => {
          # register a node to the Echidna framework
          "exec" => \&node_register,
          "acl" => 128,
        },
        "unregister_node" => {
          # unregister a node from the Echidna framework
          "exec" => \&node_unregister,
          "acl" => 128,
        },
        "update_node" => {
          # update a node's details on the Echidna framework
          "exec" => \&node_update,
          "acl" => 128,
        },
        "register_client" => {
          # register a client to the Echidna framework
          "exec" => \&client_register,
          "acl" => 127,
        },
        "unregister_client" => {
          # unregister a client from the Echidna framework
          "exec" => \&client_unregister,
          "acl" => 127,
        },
        "update_client" => {
          # update a client's details on the Echidna framework
          "exec" => \&client_update,
          "acl" => 127,
        },

        "subscribe_agent" => {
          # subscribe to an agent's, and all subordinate nodes', broadcasts
          "exec" => sub{ },
          "acl" => 127,
        },
        "unsubscribe_agent" => {
          # unsubscribe from an agent's, and all subordinate nodes', broadcasts
          "exec" => sub{ },
          "acl" => 127,
        },
        "subscribe_node" => {
          # subscribe to a node's broadcasts
          "exec" => sub{ },
          "acl" => 127,
        },
        "unsubscribe_node" => {
          # Unsubscribe from a node's broadcasts
          "exec" => sub{ },
          "acl" => 127,
        },

        "server_version" => {
          # returns the Version and revision of the Echidna server
          "exec" => \&get_server_version,
          "acl" => 127,
        },
        "server_uptime" => {
          # returns the current uptime, in seconds, of the Echidna server
          "exec" => \&get_server_uptime,
          "acl" => 127,
        },


        "nodes_connected" => {
            # return all nodes connected
            "exec" => \&get_nodes_connected,
            "acl" => 127,
        },
        "node_info" => {
            # return node info
            "exec" => \&get_node_info,
            "acl" => 127,
        },

        "clients_connected" => {
            # return all clients connected
            "exec" => \&get_clients_connected,
            "acl" => 127,
        },
        "client_info" => {
            # return client info
            "exec" => \&get_client_info,
            "acl" => 127,
        },


        "node_version" => {
          # returns the Version and revision of the specified Echidna node
          "exec" => \&get_node_version,
          "acl" => 127,
        },
        "node_uptime" => {
          # returns the current uptime, in seconds, of the specified Echidna node
          "exec" => \&get_node_uptime,
          "acl" => 127,
        },



        "search_agent" => {
            # search for agents
            "exec" => \&get_event_details,
            "acl" => 255,
        },
        "search_node" => {
            # search for nodes
            "exec" => \&get_event_details,
            "acl" => 255,
        },
        "search_client" => {
            # search for clients
            "exec" => \&get_event_details,
            "acl" => 255,
        },
        "search_event" => {
            # search for events
            "exec" => \&get_event_details,
            "acl" => 0,
        },
        "search_session" => {
            # search for sessions
            "exec" => \&get_session_details,
            "acl" => 0,
        },
        "search_data" => {
            # search for full-content data
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






sub get_modules_available
{
    my ($self, $params, $callback) = @_;

    return if( ref($callback) ne 'CODE' );

    $callback->($modules);
}


#
# CORE REGISTRATION
#

sub agent_register {
    my ($self, $params, $callback) = @_;

    return if( ref($callback) ne 'CODE' );

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->insert({
        agent => $params
    });

    $callback->($ret);
}

sub agent_unregister {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    if ( ! defined_args($params->{id}) ) {
        $callback->(1);
    }

    # remove the agent and subordinate nodes
    my $ret = $db->delete({
        agent => {
            id => $params->{id}
        }
    });

    $callback->($ret);
}

sub agent_update {
    my ($self, $params, $callback) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->update({
        agent => $params
    },
    {
        id => $params->{id}
    });

    $callback->($ret);
}

sub node_register {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->insert({
        node => $params
    });

    $callback->($ret);
}

sub node_unregister {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    # remove the node
    my $ret = $db->delete({
        node => {
            id => $params->{id}
        }
    });

    $callback->($ret);
}

sub node_update {
    my ($self, $params, $callback) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->update({
        node => $params
    },
    {
        id => $params->{id}
    });

    $callback->($ret);
}

sub client_register {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->insert({
        client => $params
    });

    $callback->($ret);
}

sub client_unregister {
    my ($self, $params, $callback) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->delete({
        client => {
            id => $params->{id}
        }
    });

    $callback->($ret);
}

sub client_update {
    my ($self, $params, $callback) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->update({
        client => $params
    },
    {
        id => $params->{id}
    });

    $callback->($ret);
}


#
# CORE SUBSCRIPTION
#

sub agent_subscribe {
    my ($self, $params, $callback) = @_;

}

sub agent_unsubscribe {
    my ($self, $params, $callback) = @_;

}

sub node_subscribe {
    my ($self, $params, $callback) = @_;

}

sub node_unsubscribe {
    my ($self, $params, $callback) = @_;

}


#
# CORE GENERAL REQUESTS
#

sub get_server_version {
    my ($self, $params, $callback) = @_;

    my $version = $nsmf->{__version};

    $callback->($version);
}

sub get_server_uptime {
    my ($self, $params, $callback) = @_;

    my $uptime = time() - $nsmf->{__started};

    $callback->($uptime);
}

sub get_server_queue {
    my ($self, $params, $callback) = @_;

}

sub get_server_status {
    my ($self, $params, $callback) = @_;

}

sub get_node_version {
    my ($self, $params, $callback) = @_;

    $logger->debug($params);

    $params->{id} //= -1;

    if ( $params->{id} <= 0 ) {
        $callback->('Invalid node ID specified.');
    }

    my $nodes = NSMF::Server->nodes();

    if( ! defined($nodes->{$params->{id}}) ) {
        $callback->('Specified node ID is not connected.');
    }

    my $ret = POE::Kernel->call($nodes->{$params->{id}}, 'get', 'get_node_version', sub {
        my ($s, $k, $h, $j) = @_;

        my $r = $j->{result} // $j->{error};
        $callback->($r);
    });

    if ( $ret ) {
        $logger->error("Possible error: " . $ret)
    }
}

sub get_node_uptime {
    my ($self, $params, $callback) = @_;

    $logger->debug($params);

    $params->{id} //= -1;

    if ( $params->{id} <= 0 ) {
        $callback->('Invalid node ID specified.');
    }

    my $nodes = NSMF::Server->nodes();

    if( ! defined($nodes->{$params->{id}}) ) {
        $callback->('Specified node ID is not connected.');
    }

    my $ret = POE::Kernel->call($nodes->{$params->{id}}, 'get', 'get_node_uptime', sub {
        my ($s, $k, $h, $j) = @_;

        my $r = $j->{result} // $j->{error};
        $callback->($r);
    });

    if ( $ret ) {
        $logger->error("Possible error: " . $ret)
    }
}

sub get_node_queue {
    my ($self, $params, $callback) = @_;

}

sub get_node_status {
    my ($self, $params, $callback) = @_;

}


sub get_plugins_loaded {
    my ($self, $params, $callback) = @_;

}

sub get_plugin_info {
    my ($self, $params, $callback) = @_;

}


sub get_clients_connected {
    my ($self, $params, $callback) = @_;

    my $clients = $nsmf->clients();

    $callback->($clients);
}

sub get_client_info {
    my ($self, $params, $callback) = @_;

}


sub get_nodes_connected {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $nodes = [];

    my $ret = $db->search({
        node => {
            state => 1
        }
    });

    if ( @{ $ret } )
    {
        foreach my $r ( @{ $ret } ) {
            push( @{ $nodes }, {
                id => $r->{id},
                name => $r->{name},
                type => $r->{type},
                description => $r->{description} // 'No description.'
            });
        }
    }

    $callback->($nodes);
}

sub get_node_info {
    my ($self, $params, $callback) = @_;

}



#
# CORE STRUCTURE SEARCHES
#

sub get_agent_details {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        agent => $params
    });

    $callback->($ret);
}

sub get_node_details {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        node => $params
    });

    $callback->($ret);
}

sub get_client_details {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        client => $params
    });

    $callback->($ret);
}

sub get_event_details {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        event => $params
    });

    $callback->($ret);
}

sub get_session_details {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params

    my $ret = $db->search({
        session => $params
    });

    $callback->($ret);
}

sub get_data_details {
    my ($self, $params, $callback) = @_;

    my $db = NSMF::Server->database();

    $logger->debug($params);

    # TODO validate, process the params and $callback->(the result

    $callback->("TODO: implement me");
}

1;
