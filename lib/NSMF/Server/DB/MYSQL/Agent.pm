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
package NSMF::Server::DB::MYSQL::Agent;

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
    AGENT_VERSION => 1
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
    return 1 if ( $self->create_tables_agent() );

    # failed
    return 0;
}

sub validate {
    my ($self) = shift;

    my $version = $self->version_get('agent');

    return ( $self->version_get('agent') == AGENT_VERSION );
}

#
# DATA OBJECT QUERY AND MANIPULATION
#

sub insert {
#    $logger->warn('Base insert method needs to be overridden.');
}

sub search {
    my ($self, $filter) = @_;

    # build up the search criteria
    my $sql = 'SELECT * FROM agent ';
    my @where = ();

    while ( my ($key, $value) = each(%{ $filter }) ) {
        $value = "'$value'" if ( $value =~ m/[^\d]/ );
        push(@where, $key . '=' . $value);
    }

    $sql .= 'WHERE ' . join(' AND ', @where);

    my $sth = $self->{__handle}->prepare($sql);
    $sth->execute();

    my $ret = [];

    while (my $row = $sth->fetchrow_hashref) {
        push(@{ $ret }, $row);
    };

    return $ret;
}

sub delete {
#    $logger->warn('Base insert method needs to be overridden.');
}


#
# TABLE CREATION
#

sub create_tables_agent {
    my ($self) = shift;

    $logger->debug('    Creating AGENT tables.');

    my $sql = '
CREATE TABLE agent (
    id          INT         NOT NULL AUTO_INCREMENT,
    name        VARCHAR(64) NOT NULL ,
    password    VARCHAR(64) NOT NULL ,
    description TEXT        NULL ,
    ip          VARCHAR(16) NOT NULL ,
    network     VARCHAR(64) NULL ,
    active      TINYINT(1)  NOT NULL DEFAULT 0 ,
    PRIMARY KEY (id)
);';

    $self->{__handle}->do($sql);

    return ( $self->version_set('agent', AGENT_VERSION) );
}

1;
