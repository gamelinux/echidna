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
    TABLE_VERSION => 1
};

#
# DATA STORE CREATION AND VALIDATION
#


sub create {
    my ($self, $handle) = @_;

    $self->{__handle} = $handle;

    # validate tables to see if they exist
    return 1 if ( $self->validate() );

    # create node tables

    # failed
    return 0;
}

sub validate {
    my ($self) = shift;

    my $sth = $self->{__handle}->prepare('SELECT version FROM versions WHERE table="node"');

    $sth->execute();
    my $r = $sth->fetchall_arrayref();

    # our table is valid if the node table exists and is the version expected
    return 1 if ( @{ $r } && $r->[0][0] == TABLE_VERSION );

    # failed
    return 0;
}

#
# DATA OBJECT QUERY AND MANIPULATION
#

sub insert {
#    $logger->warn('Base insert method needs to be overridden.');
}

sub search {
#    $logger->warn('Base insert method needs to be overridden.');
}

sub delete {
#    $logger->warn('Base insert method needs to be overridden.');
}


#
# TABLE CREATION
#

sub create_tables_node {
    my ($self) = shift;

    my $sql;

    $sql = '
CREATE TABLE IF NOT EXISTS node (
   id          INT          NOT NULL AUTO_INCREMENT,
   name        VARCHAR(64)  NOT NULL ,
   description TEXT         NULL ,
   type        VARCHAR(64)  NOT NULL ,
   PRIMARY KEY (`node_id`)
);';

    $self->{__handle}->do($sql);

    $sql = '
CREATE UNIQUE INDEX name_UNIQUE ON node (name ASC);
    ';

    $self->{__handle}->do($sql);
}


1;
