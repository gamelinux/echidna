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
package NSMF::Server::DB::MONGODB::Base;

use warnings;
use strict;
use v5.10;

#
# NSMF INCLUDES
#
use NSMF::Common::Registry;

#
# GLOBALS
#
my $logger = NSMF::Common::Registry->get('log');

#
# CONSTRUCTOR
#
sub new {
    my ($class) = shift;

    return bless({
        __handle => undef,
    }, $class);
}

#
# VERSION HELPERS
#

sub create_tables_version {
    my ($self) = shift;

    my $sql;

    $sql = '
CREATE TABLE IF NOT EXISTS versions (
   name        VARCHAR(64)  NOT NULL ,
   version     INTEGER      NOT NULL ,
   PRIMARY KEY (name)
);';

    $self->{__handle}->do($sql);
}

sub version_set {
  my ($self, $table, $version) = @_;

  #
  $self->create_tables_version();

  my $sql;

  if ( $self->version_get($table) < 0 )
  {
      $sql = 'INSERT INTO versions VALUES ("' . $table . '", ' . $version . ')';
  }
  else
  {
      $sql = 'UPDATE versions SET version=' . $version . ' WHERE name="' . $table . '"';
  }

  return ( $self->{__handle}->do($sql) > 0);
}

sub version_get {
    my ($self, $table) = @_;

    my $sth = $self->{__handle}->prepare('SELECT version FROM versions WHERE name="' . $table . '"');

    $sth->execute();
    my $r = $sth->fetchall_arrayref();

    return -1 if ( @{ $r } == 0 );

    return $r->[0][0];
}



#
# DATA STORE CREATION AND VALIDATION
#

sub create {
    $logger->warn('    Base create method needs to be overridden.');

    return 0;
}

sub validate {
    $logger->warn('    Base validate method needs to be overridden.');

    return 0;
}

#
# DATA OBJECT QUERY AND MANIPULATION
#

sub insert {
    $logger->warn('    Base insert method needs to be overridden.');
}

sub search {
    $logger->warn('    Base search method needs to be overridden.');
}

sub update {
    $logger->warn('    Base update method needs to be overridden.');
}

sub delete {
    $logger->warn('    Base delete method needs to be overridden.');
}

1;
