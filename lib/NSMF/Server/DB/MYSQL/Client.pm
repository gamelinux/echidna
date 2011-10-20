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
package NSMF::Server::DB::MYSQL::Client;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Server::DB::MYSQL::Base);

#
# PERL CONSTANTS
#
use Data::Dumper;
use Digest::SHA qw(sha256_hex);

#
# CONSTANTS
#
use constant {
    CLIENT_VERSION => 1
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
    return 1 if ( $self->create_tables_client() );

    # failed
    return 0;
}

sub validate {
    my ($self) = shift;

    my $version = $self->version_get('client');

    return ( $self->version_get('client') == CLIENT_VERSION );
}

#
# DATA OBJECT QUERY AND MANIPULATION
#

sub insert {
    my ($self, $data) = @_;

    my $sql = 'INSERT INTO client ';

    my @fields = ();
    my @values = ();

    while ( my ($key, $value) = each(%{ $data }) ) {
        $value = "'$value'" if ( $value =~ m/[^\d]/ );
        push(@fields, $key);
        push(@values, $value);
    }

    $sql .= '(updated, ' . join(',', @fields) . ') VALUES (NOW(), ' . join(',', @values) . ')';

    $self->{__handle}->do($sql);
}

sub search {
    my ($self, $filter) = @_;

    my $sql = 'SELECT * FROM client ' . $self->create_filter($filter);

    my $sth = $self->{__handle}->prepare($sql);
    $sth->execute();

    my $ret = [];

    my $client_id;
    my $client_name;
    my $client_password;
    my $client_description;
    my $client_level;
    my $client_timestamp;

    $sth->bind_columns(
        \$client_id,
        \$client_name,
        \$client_password,
        \$client_description,
        \$client_level,
        \$client_timestamp
    );

    while (my $row = $sth->fetchrow_hashref) {
        push(@{ $ret }, {
            "id" => $client_id,
            "name" => $client_name,
            "password" => $client_password,
            "description" => $client_description,
            "level" => $client_level,
            "status_timestamp" => $client_timestamp,
        });
    }

    return $ret;
}

sub delete {
    my ($self, $filter) = @_;

    my $sql = 'DELETE FROM client ' . $self->create_filter($filter);

    $self->{__handle}->do($sql);
}

#
# TABLE CREATION
#

sub create_tables_client {
    my ($self) = shift;

    $logger->debug('    Creating client tables.');

    my $sql = '
CREATE TABLE client (
    id          BIGINT      NOT NULL AUTO_INCREMENT,
    name        VARCHAR(64) NOT NULL ,
    password    VARCHAR(64) NOT NULL ,
    description TEXT        NULL ,
    level       TINYINT(1)  NOT NULL DEFAULT 0 ,
    updated     DATETIME    NOT NULL,
    PRIMARY KEY (id)
);';

    $self->{__handle}->do($sql);

    # DEV DATA ONLY
    # TODO: REMOVE WHEN CLIENT INPUT IMPLEMENTED

    $logger->info('Inserting DEV/DEMO data');

    $self->insert({
        name => 'admin',
        password => sha256_hex("admin"),
        level => 255
    });

    # END DEV DATA

    return ( $self->version_set('client', CLIENT_VERSION) );
}

1;
