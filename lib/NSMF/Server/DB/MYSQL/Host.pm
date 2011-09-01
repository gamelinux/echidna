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
package NSMF::Server::DB::MYSQL::Host;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Server::DB::MYSQL::Base);

#
# PERL CONSTANTS
#
use Data::Dumper;
use JSON;

#
# CONSTANTS
#
use constant {
    HOST_VERSION => 1
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

    return 0 if ( ! $self->create_functions_host() );

    # validate tables to see if they exist
    return 1 if ( $self->validate() );

    # create host functions
    return 1 if ( $self->create_tables_host() );

    # failed
    return 0;
}

sub validate {
    my ($self) = shift;

    my $version = $self->version_get('host');

    return ( $self->version_get('host') == HOST_VERSION );
}

#
# DATA OBJECT QUERY AND MANIPULATION
#

sub insert {
    my ($self, $data) = @_;

    if ( ref($data) ne 'HASH' )
    {
        $logger->debug('Expected a HASH reference describing a Host. Got: ' . ref($data));
        return 0;
    }


    # validate input


    # set sane defaults for optional
    $data->{data}{ip}          //=  0; # "81.29.231.51"
    $data->{data}{type}        //= ''; # "SYN" (SYN,RST,SERVER,CLIENT,REPUTUATION.... etc)
    $data->{data}{type_data}   //= ''; # "S4:57:1:60:M1460,S,T,N,W7:.:"

    $data->{data}{node}        //=  0; # "sensor1" - name of the node that recorded the data
    $data->{data}{port}        //=  0; # "80"
    $data->{data}{proto}       //=  0; # "6" (tcp/udp/icmp...)
    $data->{data}{os}          //=  0; # "Linux"
    $data->{data}{os_details}  //= ''; # "2.6 (newer, 7)"
    $data->{data}{timestamp}   //=  0; # "1303520845"
    $data->{data}{type}        //= ''; # "SYN" (SYN,RST,SERVER,CLIENT.... etc) Repetuation :)
    $data->{data}{type_data}   //= ''; # "S4:57:1:60:M1460,S,T,N,W7:.:"
                                       # if type == CLIENT -> "http:Mozilla/5.0 (X11; Linux x86_64; rv:2.0) Gecko/20100101 Firefox/4.0"
    $data->{data}{mac}         //=  0; # "51:52:01:3c:4d:d8"
    $data->{data}{hostname}    //= ''; # "vinself" etc.
    $data->{data}{distance}    //=  0; # "7" ect. (from TTL)
    $data->{data}{extra}       //= ''; # "link:ethernet/modem:uptime:11769hrs"

    $data->{vendor_meta}    //= {};

    my $sql = 'INSERT INTO host (ip, type, type_data, node_id, port, protocol, os, os_details, timestamp, mac, hostname, distance, extra) VALUES (' .
        join(",", (
            'INET_PTON("'.$data->{ip}.'")',
            $data->{type},
            $data->{type_data},
            $data->{node_id},
            $data->{port},
            $data->{proto},
            $data->{os},
            $data->{os_details},
            $self->{__handle}->quote($data->{timestamp}),
            $data->{mac},
            $data->{hostname},
            $data->{distance},
            $data->{extra},
        )). ')';

    $logger->debug("SQL: $sql");

    # expect a single row to be inserted
    my $rows = $self->{__handle}->do($sql) // 0;

    return ($rows == 1);
}

sub search {
    my ($self, $filter) = @_;

    my $sql = 'SELECT * FROM host ' . $self->create_filter($filter);

    my $sth = $self->{__handle}->prepare($sql);
    $sth->execute();

    my $ret = [];

    while (my $row = $sth->fetchrow_hashref) {
        push(@{ $ret }, $row);
    };

    return $ret;
}

sub custom {
    my ($self, $method, $filter) = @_;

    if( $method eq "host_id_max" ) {
        return $self->host_id_max($filter);
    }

    return [];
}

#
# VENDOR DATA
#


#
# CUSTOM METHODS
#

# Taken from EVENT, not usable here... but left here for now
sub host_id_max {
    my ($self, $filter) = @_;

    my $sql = 'SELECT IFNULL(MAX(ip), 0) as host_id_max FROM host ' . $self->create_filter($filter);

    my $sth = $self->{__handle}->prepare($sql);
    $sth->execute();

    my $ret = $sth->fetchall_arrayref();

    # result will be single row, single value (ie. [0][0])
    return $ret->[0][0];
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

sub create_tables_host {
    my ($self) = shift;

    $logger->debug('    Creating HOST tables.');

    my $sql = '
CREATE TABLE host (
   ip              DECIMAL(39)  NOT NULL ,
   type            INT          NOT NULL ,
   type_data       TEXT         NOT NULL ,
   node_id         BIGINT       NOT NULL ,
   port            SMALLINT     NOT NULL ,
   protocol        TINYINT      NOT NULL ,
   os              TEXT         NOT NULL ,
   os_details      TEXT         NOT NULL ,
   timestamp       DATETIME     NOT NULL ,
   mac             INT          NOT NULL ,
   hostname        TEXT         NOT NULL ,
   distance        SMALLINT     NOT NULL ,
   extra           TEXT,
   PRIMARY KEY (ip)
)';

    return 0 if ( ! $self->{__handle}->do($sql) );

    return ( $self->version_set('host', HOST_VERSION) );
}

#
# STORED FUNCTION CREATION
#

sub create_functions_host {
    my ($self) = shift;

    $logger->debug('    Creating HOST functions.');

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
