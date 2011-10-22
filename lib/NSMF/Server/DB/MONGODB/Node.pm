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
package NSMF::Server::DB::MONGODB::Node;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Server::DB::MONGODB::Base);

#
# PERL CONSTANTS
#
use Data::Dumper;
use NSMF::Common::Registry;

#
# CONSTANTS
#
use constant {
    NODE_VERSION => 1
};

#
# GLOBALS
#
my $logger = NSMF::Common::Registry->get('log');

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

#    $logger->warn('Base insert method needs to be overridden.');
}

sub search {
    my ($self, $filter) = @_;

    $logger->debug('Looking for an node?');
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
   id          INT          NOT NULL AUTO_INCREMENT,
   name        VARCHAR(64)  NOT NULL ,
   description TEXT         NULL ,
   type        VARCHAR(64)  NOT NULL ,
   PRIMARY KEY (id),
   UNIQUE KEY name_UNIQUE (name)
);';

    $self->{__handle}->do($sql);

    return ( $self->version_set('node', NODE_VERSION) );
}

1;
