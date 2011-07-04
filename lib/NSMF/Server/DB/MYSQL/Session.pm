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
    SESSION_VERSION => 1
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

    return 0 if ( ! $self->create_functions_session() );

    # validate tables to see if they exist
    return 1 if ( $self->validate() );

    # create session functions
    return 1 if ( $self->create_tables_session() );

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

    return 0 if ( ref($data) ne 'HASH' );

    # validate input


    # set sane defaults for optional
    $data->{data}{filename} //= '';
    $data->{data}{offset} //= 0;
    $data->{data}{length} //= 0;
    $data->{vendor_meta} //= '';

    my $sql = '
INSERT INTO session
 (session_id, timestamp, times_end, times_start, times_duration, node_id, net_version, net_protocol, net_src_ip, net_src_port, net_src_packets, net_src_bytes, net_src_flags, net_dst_ip, net_dst_port, net_dst_packets, net_dst_bytes, net_dst_flags, data_filename, data_offset, data_length) VALUES (' .
        $data->{session}{id} . ',' .
        $data->{session}{timestam} . ',' .
        $data->{session}{times}{start} . ',' .
        $data->{session}{times}{end} . ',' .
        $data->{session}{times}{duration} . ',' .
        $data->{node}{id} . ',' .
        $data->{net}{version} . ',' .
        $data->{net}{protocol} . ',' .
        $data->{net}{src}{ip} . ',' .
        $data->{net}{src}{port} . ',' .
        $data->{net}{src}{total_packets} . ',' .
        $data->{net}{src}{total_bytes} . ',' .
        $data->{net}{src}{flags} . ',' .
        $data->{net}{dst}{ip} . ',' .
        $data->{net}{dst}{port} . ',' .
        $data->{net}{dst}{total_packets} . ',' .
        $data->{net}{dst}{total_bytes} . ',' .
        $data->{net}{dst}{flags} . ',"' .
        $data->{data}{filename} . '",' .
        $data->{data}{offset} . ',' .
        $data->{data}{length} . ')';

    return ( ! $self->{__handle}->do($sql) );
}

sub search {
    my ($self, $filter) = @_;

    $logger->debug('Looking for an session?');
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

sub create_tables_session {
    my ($self) = shift;

    $logger->debug('    Creating SESSION tables.');

    my $sql = '
CREATE TABLE session (
   session_id      BIGINT       NOT NULL ,
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
   vendor_meta     TEXT,
   PRIMARY KEY (session_id)
)';

    return 0 if ( ! $self->{__handle}->do($sql) );

    return ( $self->version_set('session', SESSION_VERSION) );
}

#
# STORED FUNCTINO CREATION
#

sub create_functions_session {
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

        return 0 if ( ! $self->{__handle}->do($sql) );
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
    SET a := CONCAT_WS(":", LPAD(CONV(r, 10, 16), 4, "0"), a);

    SET i := i - 1;
  END WHILE;

  SET a := TRIM(TRAILING ":" FROM CONCAT_WS(":",
                                            LPAD(CONV(n, 10, 16), 4, "0"),
                                            a));

  RETURN a;
END;
//
DELIMITER ;
';
        return 0 if ( ! $self->{__handle}->do($sql) );
    }

    # success
    return 1;
}

1;
