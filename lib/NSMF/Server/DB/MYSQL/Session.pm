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
    $data->{data}{filename}        //= '';
    $data->{data}{offset}          //=  0;
    $data->{data}{length}          //=  0;
    $data->{meta}                  //= '';
    # set sane defaults for missing required fields (should not happen)
    $data->{net_src_total_packets} //=  0;
    $data->{net_dst_total_packets} //=  0;
    $data->{net_src_total_bytes}   //=  0;
    $data->{net_dst_total_bytes}   //=  0;
    $data->{net_src_flags}         //=  0;
    $data->{net_dst_flags}         //=  0;


    my $sql = 'INSERT INTO session (id, timestamp, time_start, time_end, time_duration, node_id, net_version, net_protocol, net_src_ip, net_src_port, net_src_total_packets, net_src_total_bytes, net_src_flags, net_dst_ip, net_dst_port, net_dst_total_packets, net_dst_total_bytes, net_dst_flags, data_filename, data_offset, data_length) VALUES (' .
        join(",", (
            $data->{id},
            '"'.$data->{timestamp}.'"',
            '"'.$data->{time_start}.'"',
            '"'.$data->{time_end}.'"',
            $data->{time_duration},
            $data->{node_id},
            $data->{net_version},
            $data->{net_protocol},
            'INET_PTON("'.$data->{net_src_ip}.'")',
            $data->{net_src_port},
            $data->{net_src_total_packets},
            $data->{net_src_total_bytes},
            $data->{net_src_flags},
            'INET_PTON("'.$data->{net_dst_ip}.'")',
            $data->{net_dst_port},
            $data->{net_dst_total_packets},
            $data->{net_dst_total_bytes},
            $data->{net_dst_flags},
            '"'.$data->{data_filename}.'"',
            $data->{data_offset},
            $data->{data_length}
        )). ')';

    $logger->debug("SQL: $sql");

    # expect a single row to be inserted
    return ( $self->{__handle}->do($sql) == 1 );
}

sub search {
    my ($self, $filter) = @_;

    my $sql = 'SELECT * FROM session ' . $self->create_filter($filter);

    my $sth = $self->{__handle}->prepare($sql);
    $sth->execute();

    my $ret = [];

    while (my $row = $sth->fetchrow_hashref) {
        push(@{ $ret }, $row);
    };

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

sub create_tables_session {
    my ($self) = shift;

    $logger->debug('    Creating SESSION tables.');

    my $sql = '
CREATE TABLE session (
   id                    BIGINT       NOT NULL ,
   timestamp             DATETIME     NOT NULL ,
   time_start            DATETIME     NOT NULL ,
   time_end              DATETIME     NOT NULL ,
   time_duration         BIGINT       NOT NULL ,
   node_id               BIGINT       NOT NULL ,
   net_version           INT          NOT NULL ,
   net_protocol          TINYINT      NOT NULL ,
   net_src_ip            DECIMAL(39)  NOT NULL ,
   net_src_port          SMALLINT     NOT NULL ,
   net_src_total_packets BIGINT       NOT NULL ,
   net_src_total_bytes   BIGINT       NOT NULL ,
   net_src_flags         TINYINT      NOT NULL ,
   net_dst_ip            DECIMAL(39)  NOT NULL ,
   net_dst_port          SMALLINT     NOT NULL ,
   net_dst_total_packets BIGINT       NOT NULL ,
   net_dst_total_bytes   BIGINT       NOT NULL ,
   net_dst_flags         TINYINT      NOT NULL ,
   data_filename         TEXT         NOT NULL ,
   data_offset           BIGINT       NOT NULL ,
   data_length           BIGINT       NOT NULL ,
   meta                  TEXT,
   PRIMARY KEY (id)
)';

    return 0 if ( ! $self->{__handle}->do($sql) );

    return ( $self->version_set('session', SESSION_VERSION) );
}

#
# STORED FUNCTION CREATION
#

sub create_functions_session {
    my ($self) = shift;

    $logger->debug('    Creating SESSION functions.');

    # create function for translating IPV6 address to numeric
    if ( $self->{__handle}->do('SHOW FUNCTION STATUS WHERE name="INET_PTON"') == 0 ) {
        my $sql = "
CREATE FUNCTION INET_PTON(n CHAR(39))
RETURNS DECIMAL(39) UNSIGNED
DETERMINISTIC
BEGIN
  DECLARE p INT      DEFAULT 1;
  DECLARE i INT      DEFAULT 1;
  DECLARE l INT      DEFAULT 0;
  DECLARE s INT      DEFAULT 0;
  DECLARE a CHAR(39) DEFAULT '';

  -- assume dotted notation is IPv4
  IF INSTR(n, '.') > 0 THEN
    -- produce an IPv4 mapped to IPv6 address
    RETURN CAST(INET_ATON(n) AS DECIMAL(39)) + 281470681743360;

  -- otherwise we assume IPv6
  ELSE
    SET s := LENGTH(n) - LENGTH(REPLACE(n, ':', ''));

    -- check if we are of the very short form
    IF INSTR(n, '::') = 1 THEN
      SET n := TRIM(LEADING ':' FROM REPLACE(n, '::', ':0000:0000:0000:0000:0000:0000:0000:'));
    -- check if we have some compressed zeroes
    ELSEIF s < 7 THEN
        SET n := REPLACE(n, '::', CONCAT(REPEAT(':0000', 8-s), ':'));
    END IF;

    SET l := LENGTH(n);

    WHILE i <= l DO
      SET p := LOCATE(':', n, i);
      IF p > 0 THEN
        SET a := CONCAT(a, ':', LPAD(SUBSTR(n, i, p-i), 4, '0'));
        SET i := p + 1;
      ELSE
        SET a := CONCAT(TRIM(LEADING ':' FROM a), ':', LPAD(SUBSTR(n, i, l-i+1), 4, '0'));
        SET i := l+1;
      END IF;
    END WHILE;

    RETURN CAST(CONV(SUBSTRING(a FROM  1 FOR 4), 16, 10) AS DECIMAL(39))
                       * 5192296858534827628530496329220096 -- 65536 ^ 7
         + CAST(CONV(SUBSTRING(a FROM  6 FOR 4), 16, 10) AS DECIMAL(39))
                       *      79228162514264337593543950336 -- 65536 ^ 6
         + CAST(CONV(SUBSTRING(a FROM 11 FOR 4), 16, 10) AS DECIMAL(39))
                       *          1208925819614629174706176 -- 65536 ^ 5
         + CAST(CONV(SUBSTRING(a FROM 16 FOR 4), 16, 10) AS DECIMAL(39))
                       *               18446744073709551616 -- 65536 ^ 4
         + CAST(CONV(SUBSTRING(a FROM 21 FOR 4), 16, 10) AS DECIMAL(39))
                       *                    281474976710656 -- 65536 ^ 3
         + CAST(CONV(SUBSTRING(a FROM 26 FOR 4), 16, 10) AS DECIMAL(39))
                       *                         4294967296 -- 65536 ^ 2
         + CAST(CONV(SUBSTRING(a FROM 31 FOR 4), 16, 10) AS DECIMAL(39))
                       *                              65536 -- 65536 ^ 1
         + CAST(CONV(SUBSTRING(a FROM 36 FOR 4), 16, 10) AS DECIMAL(39))
         ;
  END IF;
END;
";

        return 0 if ( ! $self->{__handle}->do($sql) );
    }

    # create function for translating IPV6 numeric to address
    if ( $self->{__handle}->do('SHOW FUNCTION STATUS WHERE name="INET_NTOP"') == 0 ) {
        my $sql = "
CREATE FUNCTION INET_NTOP(n DECIMAL(39) UNSIGNED)
RETURNS CHAR(39)
DETERMINISTIC
BEGIN
  DECLARE a CHAR(39)             DEFAULT '';
  DECLARE i INT                  DEFAULT 7;
  DECLARE q DECIMAL(39) UNSIGNED DEFAULT 0;
  DECLARE r INT                  DEFAULT 0;

  -- check if we are an IPv4 mapped IPv6 address
  IF (n < 281474976710656) AND ((n & 281470681743360) = 281470681743360) THEN
    SET a := INET_NTOA(n - 281470681743360);

  -- otherwise assume we're IPv6
  ELSE
    WHILE i DO
      -- DIV doesn't work with numbers > BIGINT
      SET q := FLOOR(n / 65536);
      SET r := n MOD 65536;
      SET n := q;
      SET a := CONCAT_WS(':', LPAD(CONV(r, 10, 16), 4, '0'), a);

      SET i := i - 1;
    END WHILE;

    SET a := TRIM(TRAILING ':' FROM CONCAT_WS(':', LPAD(CONV(n, 10, 16), 4, '0'), a));
  END IF;

  RETURN a;
END;
";
        return 0 if ( ! $self->{__handle}->do($sql) );
    }

    # success
    return 1;
}

1;
