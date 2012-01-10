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

#
# NSMF INCLUDES
#
use NSMF::Server;
use NSMF::Common::Registry;

#
# GLOBALS
#

my $logger = NSMF::Common::Registry->get('log')
    // carp 'Got an empty config object from Registry';

#
# MEMBERS
#

sub get_registered_methods {
    my ($self) = @_;

    return [
        {
            # returns the available modules
            method => "modules_available",
            acl => 0,
            func => sub { $self->get_modules_available(@_); },
        },

        {
            # register an agent to the Echidna framework
            method => "register_agent",
            acl => 128,
            func => sub { $self->agent_register(@_); },
        },
        {
            # unregister an agent, and all subordinate nodes, from the Echidna framework
            method => "unregister_agent",
            acl => 128,
            func => sub { $self->agent_unregister(@_); },
        },
        {
            # update an agent's details on the Echidna framework
            method => "update_agent",
            acl => 128,
            func => sub { $self->agent_update(@_); },
        },
        {
            # register a node to the Echidna framework
            method => "register_node",
            acl => 128,
            func => sub { $self->node_register(@_); },
        },
        {
            # unregister a node from the Echidna framework
            method => "unregister_node",
            acl => 128,
            func => sub { $self->node_unregister(@_); },
        },
        {
            # update a node's details on the Echidna framework
            method => "update_node",
            acl => 128,
            func => sub { $self->node_update(@_); },
        },
        {
            # register a client to the Echidna framework
            method => "register_client",
            acl => 127,
            func => sub { $self->client_register(@_); },
        },
        {
            # unregister a client from the Echidna framework
            method => "unregister_client",
            acl => 127,
            func => sub { $self->client_unregister(@_); },
        },
        {
            # update a client's details on the Echidna framework
            method => "update_client",
            acl => 127,
            func => sub { $self->client_update(@_); },
        },

        {
            # subscribe to an agent's, and all subordinate nodes', broadcasts
            method => "subscribe_agent",
            acl => 127,
            func => sub{ },
        },
        {
            # unsubscribe from an agent's, and all subordinate nodes', broadcasts
            method => "unsubscribe_agent",
            acl => 127,
            func => sub{ },
        },
        {
            # subscribe to a node's broadcasts
            method => "subscribe_node",
            acl => 127,
            func => sub{ },
        },
        {
            # Unsubscribe from a node's broadcasts
            method => "unsubscribe_node",
            acl => 127,
            func => sub{ },
        },

        {
            method => "server_version",
            # returns the Version and revision of the Echidna server
            acl => 127,
            func => sub { $self->get_server_version(@_); },
        },
        {
            # returns the current uptime, in seconds, of the Echidna server
            method => "server_uptime",
            acl => 127,
            func => sub { $self->get_server_uptime(@_); },
        },

        {
            # return all nodes connected
            method => "nodes_connected",
            acl => 127,
            func => sub { $self->get_nodes_connected(@_); },
        },
        {
            # return node info
            method => "node_info",
            acl => 127,
            func => sub { $self->get_node_info(@_); },
        },

        {
            # return all clients connected
            method => "clients_connected",
            acl => 127,
            func => sub { $self->get_clients_connected(@_); },
        },
        {
            # return client info
            method => "client_info",
            acl => 127,
            func => sub { $self->get_client_info(@_); },
        },

        {
            # returns the Version and revision of the specified Echidna node
            method => "node_version",
            acl => 127,
            func => sub { $self->get_node_version(@_); },
        },
        {
            # returns the current uptime, in seconds, of the specified Echidna node
            method => "node_uptime",
            acl => 127,
            func => sub { $self->get_node_uptime(@_); },
        },

        {
            # search for agents
            method => "search_agent",
            acl => 255,
            func => sub { $self->get_event_details(@_); },
        },
        {
            # search for nodes
            method => "search_node",
            acl => 255,
            func => sub { $self->get_event_details(@_); },
        },
        {
            # search for clients
            method => "search_client",
            acl => 255,
            func => sub { $self->get_event_details(@_); },
        },
        {
            # search for events
            method => "search_event",
            acl => 0,
            func => sub { $self->get_event_details(@_); },
        },
        {
            # search for sessions
            method => "search_session",
            acl => 0,
            func => sub { $self->get_session_details(@_); },
        },
        {
            # search for full-content data
            method => "search_data",
            acl => 0,
            func => sub { $self->get_data_details(@_); },
        },
    ];
}


sub get_modules_available {
    my ($self, $client, $json, $callback) = @_;

    $callback->( NSMF::Common::Registry->get('config')->modules() );
}


#
# CORE REGISTRATION
#

sub agent_register {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->insert({
        agent => $params
    });

    $callback->($ret);
}

sub agent_unregister {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    my $ret = 1;

    # TODO: validate params
    my $params = $json->{params};

    if ( defined_args($params->{id}) ) {
        # remove the agent and subordinate nodes
        my $ret = $db->delete({
            agent => {
                id => $params->{id}
            }
        });
    }

    $callback->($ret);
}

sub agent_update {
    my ($self, $client, $json, $callback) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->update({
        agent => $params
    },
    {
        id => $params->{id}
    });

    $callback->($ret);
}

sub node_register {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->insert({
        node => $params
    });

    $callback->($ret);
}

sub node_unregister {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    # remove the node
    my $ret = $db->delete({
        node => {
            id => $params->{id}
        }
    });

    $callback->($ret);
}

sub node_update {
    my ($self, $client, $json, $callback) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->update({
        node => $params
    },
    {
        id => $params->{id}
    });

    $callback->($ret);
}

sub client_register {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->insert({
        client => $params
    });

    $callback->($ret);
}

sub client_unregister {
    my ($self, $client, $json, $callback) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->delete({
        client => {
            id => $params->{id}
        }
    });

    $callback->($ret);
}

sub client_update {
    my ($self, $client, $json, $callback) = @_;

    # require node id
    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

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
    my ($self, $client, $json, $callback) = @_;

}

sub agent_unsubscribe {
    my ($self, $client, $json, $callback) = @_;

}

sub node_subscribe {
    my ($self, $client, $json, $callback) = @_;

}

sub node_unsubscribe {
    my ($self, $client, $json, $callback) = @_;

}


#
# CORE GENERAL REQUESTS
#

sub get_server_version {
    my ($self, $client, $json, $callback) = @_;

    my $version = NSMF::Server->instance()->{__version};

    $callback->($version);
}

sub get_server_uptime {
    my ($self, $client, $json, $callback) = @_;

    my $uptime = time();# - $echidna->{__started};

    $callback->($uptime);
}

sub get_server_queue {
    my ($self, $client, $json, $callback) = @_;

}

sub get_server_status {
    my ($self, $client, $json, $callback) = @_;

}

sub get_node_version {
    my ($self, $client, $json, $callback) = @_;

    my $params = $json->{params};
    $logger->debug($params);

    $params->{id} //= -1;

    if ( $params->{id} <= 0 ) {
        $callback->('Invalid node ID specified.');
        return;
    }

    my $nodes = NSMF::Server->nodes();

#    my $node = grep { $_->{node_details}{id} eq $params->{id} } @{ $nodes };

#    if( defined($nodes->{$params->{id}}) ) {
#        my $ret = POE::Kernel->call($nodes->{$params->{id}}, 'get', 'get_node_version', sub {
#            my ($s, $k, $h, $j) = @_;
    #
    #           my $r = $j->{result} // $j->{error};
    #           $callback->($r);
    #       });
    #     return;
    #}

    $callback->('Specified node ID is not connected.');
}

sub get_node_uptime {
    my ($self, $client, $json, $callback) = @_;


    my $params = $json->{params};
    $logger->debug($params);
    $params->{id} //= -1;

    if ( $params->{id} <= 0 ) {
        $callback->('Invalid node ID specified.');
    }

    my $nodes = NSMF::Server->nodes();

    if( ! defined($nodes->{$params->{id}}) ) {
        $callback->('Specified node ID is not connected.');
    }

    #my $ret = POE::Kernel->call($nodes->{$params->{id}}, 'get', 'get_node_uptime', sub {
    #    my ($s, $k, $h, $j) = @_;
    #
    #    my $r = $j->{result} // $j->{error};
    #    $callback->($r);
    #});

    #if ( $ret ) {
    #    $logger->error("Possible error: " . $ret)
    #}
}

sub get_node_queue {
    my ($self, $client, $json, $callback) = @_;

}

sub get_node_status {
    my ($self, $client, $json, $callback) = @_;

}


sub get_plugins_loaded {
    my ($self, $client, $json, $callback) = @_;

}

sub get_plugin_info {
    my ($self, $client, $json, $callback) = @_;

}


sub get_clients_connected {
    my ($self, $client, $json, $callback) = @_;

    my $clients = [];#$echidna->clients();

    $callback->($clients);
}

sub get_client_info {
    my ($self, $client, $json, $callback) = @_;

}


sub get_nodes_connected {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};
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
    my ($self, $client, $json, $callback) = @_;

}



#
# CORE STRUCTURE SEARCHES
#

sub get_agent_details {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->search({
        agent => $params
    });

    $callback->($ret);
}

sub get_node_details {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->search({
        node => $params
    });

    $callback->($ret);
}

sub get_client_details {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->search({
        client => $params
    });

    $callback->($ret);
}

sub get_event_details {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->search({
        event => $params
    });

    $callback->($ret);
}

sub get_session_details {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    # TODO: validate params
    my $params = $json->{params};

    my $ret = $db->search({
        session => $params
    });

    $callback->($ret);
}

sub get_data_details {
    my ($self, $client, $json, $callback) = @_;

    my $db = NSMF::Server->database();

    my $params = $json->{params};

    $logger->debug($params);

    # TODO validate, process the params and $callback->(the result

    $callback->("TODO: implement me");
}

1;
