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
package NSMF::Server::DB::MYSQL::Session;

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
    SESION_VERSION => 1
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

    my $version = $self->version_get('session');

    return ( $self->version_get('session') == SESSION_VERSION );
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

    $logger->debug('    Creating SESSION tables.');

    my $sql = '
CREATE TABLE session (
   id              BIGINT       NOT NULL AUTO_INCREMENT,
   timestamp       DATETIME     NOT NULL ,
   times_start     DATETIME     NOT NULL ,
   times_end       DATETIME     NOT NULL ,
   times_duration  DATETIME     NOT NULL ,
   node_id         BIGINT       NOT NULL ,
   net_version     INT          NOT NULL ,
   net_protocol    TINYINT      NOT NULL ,
   net_src_ip      DECIMAL(39)  NOT NULL ,
   net_src_port    SMALLINT     NOT NULL ,
   net_src_packets BIGINT       NOT NULL ,
   net_src_bytes   BIGINT       NOT NULL ,
   net_src_flags   TINYINT      NOT NULL ,
   net_dst_ip      DECIMAL(39)  NOT NULL ,
   net_dst_port    SMALLINT     NOT NULL ,
   net_dst_packets BIGINT       NOT NULL ,
   net_dst_bytes   BIGINT       NOT NULL ,
   net_dst_flags   TINYINT      NOT NULL ,
   data_filename   TEXT         NOT NULL ,
   data_offset     BIGINT       NOT NULL ,
   data_length     BIGINT       NOT NULL ,
   vendor_meta     TEXT
   PRIMARY KEY (id),
);';

    $self->{__handle}->do($sql);

    return ( $self->version_set('node', NODE_VERSION) );
}

#
# STORED FUNCTINO CREATION
#

sub create_functions_sessions {
    my ($self) = shift;

    $logger->debug('    Creating SESSION functions.');

    # create function for translating IPV6 address to numeric
    if ( ! $self->{__handle}->do('SHOW FUNCTION STATUS WHERE name="INET_ATON6"') ) {
        my $sql = '
DELIMITER //
CREATE FUNCTION INET_ATON6(n CHAR(39))
RETURNS DECIMAL(39) UNSIGNED
DETERMINISTIC
BEGIN
  RETURN CAST(CONV(SUBSTRING(n FROM  1 FOR 4), 16, 10) AS DECIMAL(39))
                     * 5082387779348759068627451506589696 -- 65535 ^ 7
       + CAST(CONV(SUBSTRING(n FROM  6 FOR 4), 16, 10) AS DECIMAL(39))
                     *      79220909236042181489028890625 -- 65535 ^ 6
       + CAST(CONV(SUBSTRING(n FROM 11 FOR 4), 16, 10) AS DECIMAL(39))
                     *          1208833588708967444709375 -- 65535 ^ 5
       + CAST(CONV(SUBSTRING(n FROM 16 FOR 4), 16, 10) AS DECIMAL(39))
                     *               18445618199572250625 -- 65535 ^ 4
       + CAST(CONV(SUBSTRING(n FROM 21 FOR 4), 16, 10) AS DECIMAL(39))
                     *                    281462092005375 -- 65535 ^ 3
       + CAST(CONV(SUBSTRING(n FROM 26 FOR 4), 16, 10) AS DECIMAL(39))
                     *                         4294836225 -- 65535 ^ 2
       + CAST(CONV(SUBSTRING(n FROM 31 FOR 4), 16, 10) AS DECIMAL(39))
                     *                              65535 -- 65535 ^ 1
       + CAST(CONV(SUBSTRING(n FROM 36 FOR 4), 16, 10) AS DECIMAL(39))
       ;
END;
//
DELIMITER ;
';

        $self->{__handle}->do($sql);
    }

    # create function for translating IPV6 numeric to address
    if ( ! $self->{__handle}->do('SHOW FUNCTION STATUS WHERE name="INET_NTOA6"') ) {
        my $sql = '
DELIMITER //
CREATE FUNCTION INET_NTOA6(n DECIMAL(39) UNSIGNED)
RETURNS CHAR(39)
DETERMINISTIC
BEGIN
  DECLARE a CHAR(39)             DEFAULT "";
  DECLARE i INT                  DEFAULT 7;
  DECLARE q DECIMAL(39) UNSIGNED DEFAULT 0;
  DECLARE r INT                  DEFAULT 0;
  WHILE i DO
    -- DIV doesnt work with numbers > BIGINT
    SET q := FLOOR(n / 65535);
    SET r := n MOD 65535;
    SET n := q;
    SET a := CONCAT_WS(":", LPAD(CONV(r, 10, 16), 4, '0'), a);

    SET i := i - 1;
  END WHILE;

  SET a := TRIM(TRAILING ":" FROM CONCAT_WS(":",
                                            LPAD(CONV(n, 10, 16), 4, '0'),
                                            a));

  RETURN a;
END;
//
DELIMITER ;
';
        $self->{__handle}->do($sql);
    }
}

1;
