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
package NSMF::Server::DB::MYSQL::Node;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Server::DB::MYSQL::Base);

#
# PERL CONSTANTS
#
use Data::Dumper;

#
# CONSTANTS
#
use constant {
    NODE_VERSION => 1
};

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

#
# DATA STORE CREATION AND VALIDATION
#


sub create {
    my ($self, $handle) = @_;

    $self->{__handle} = $handle;

    # validate tables to see if they exist
    return 1 if ( $self->validate() );

    # create node tables
    return 1 if ( $self->create_tables_node() );

    # failed
    return 0;
}

sub validate {
    my ($self) = shift;

    my $version = $self->version_get('node');

    return ( $self->version_get('node') == NODE_VERSION );
}

#
# DATA OBJECT QUERY AND MANIPULATION
#

sub insert {
    my ($self, $data) = @_;

    my $sql = 'INSERT INTO node ';

    my @fields = ();
    my @values = ();

    while ( my ($key, $value) = each(%{ $data }) ) {
        $value = "'$value'" if ( $value =~ m/[^\d]/ );
        push(@fields, $key);
        push(@values, $value);
    }

    $sql .= '(updated, ' . join(',', @fields) . ') VALUES (NOW(), ' . join(',', @values) . ')';

    $self->{__handle}->do($sql);
#    $logger->warn('Base insert method needs to be overridden.');
}

sub search {
    my ($self, $filter) = @_;

    my $sql = 'SELECT * FROM node ' . $self->create_filter($filter);

    my $sth = $self->{__handle}->prepare($sql);
    $sth->execute();

    my $ret = [];

    my $node_id;
    my $node_agent_id;
    my $node_name;
    my $node_description;
    my $node_type;
    my $node_network;
    my $node_state;
    my $node_timestamp;

    $sth->bind_columns(
        \$node_id,
        \$node_agent_id,
        \$node_name,
        \$node_description,
        \$node_type,
        \$node_network,
        \$node_state,
        \$node_timestamp
    );

    while (my $row = $sth->fetchrow_hashref) {
        push(@{ $ret }, {
            "id" => $node_id,
            "agent_id" => $node_agent_id,
            "name" => $node_name,
            "description" => $node_description,
            "type" => $node_type,
            "type" => $node_network,
            "status_state" => $node_state,
            "status_timestamp" => $node_timestamp,
        });
    }

    return $ret;
}

sub update {
    my ($self, $data, $filter) = @_;

#    $logger->warn('Base insert method needs to be overridden.');
}

sub delete {
    my ($self, $filter) = @_;

#    $logger->warn('Base insert method needs to be overridden.');
}


#
# TABLE CREATION
#

sub create_tables_node {
    my ($self) = shift;

    $logger->debug('    Creating NODE tables.');

    my $sql = '
CREATE TABLE node (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    agent_id    BIGINT       NOT NULL ,
    name        VARCHAR(64)  NOT NULL ,
    description TEXT         NULL ,
    type        VARCHAR(64)  NOT NULL ,
    network     VARCHAR(64)  NOT NULL ,
    state       TINYINT(1)   NOT NULL DEFAULT 0 ,
    updated     DATETIME     NOT NULL ,
    PRIMARY KEY (id),
    UNIQUE KEY name_UNIQUE (name)
);';

    $self->{__handle}->do($sql);

    # DEV DATA ONLY
    # TODO: REMOVE WHEN AGENT INPUT IMPLEMENTED

    $logger->info('Inserting DEV/DEMO data');

    # BARNYARD2 node
    $self->insert({
        name     => 'BARNYARD2',
        type     => 'barnyard2',
        agent_id => 1,
        network  => 'dmz'
    });

    # CXTRACKER node
    $self->insert({
        name     => 'CXTRACKER',
        type     => 'cxtracker',
        agent_id => 1,
        network  => 'dmz'
    });

    # END DEV DATA


    return ( $self->version_set('node', NODE_VERSION) );
}

1;
