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
package NSMF::Server::DB::MYSQL::Base;

use warnings;
use strict;
use v5.10;

use Data::Dumper;

#
# NSMF INCLUDES
#
use NSMF::Common::Logger;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

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

    eval {
        $sth->execute();
    };

    return -1 if ( $@ );

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

    return [];
}

sub update {
    $logger->warn('    Base update method needs to be overridden.');
}

sub delete {
    $logger->warn('    Base delete method needs to be overridden.');
}

sub custom {
    $logger->warn('    Base custom method needs to be overridden.');
};

#
# FILTER CREATION
#

sub create_filter
{
    my ($self, $filter) = @_;

    if( ref($filter) ne 'HASH' ) {
        return '';
    }

    return 'WHERE ' . $self->create_filter_from_hash($filter);
}


sub create_filter_from_hash {
    my ($self, $value, $field, $parent_field) = @_;

    if ( defined( $field ) ) {
        $value = $value->{$field};
    }

    my @fields  = keys( %{ $value } );

    return '' if ( @fields == 0 );

    my @where = ();
    my $connect = 'AND';
    my $conditional = '=';

    # build up the search criteria
    for my $f ( @fields ) {
        my $criteria = '';

        given( $f )
        {
            when(/\$eq/) { $conditional = '='; }
            when(/\$ne/) { $conditional = '!='; }
            when(/\$lt/) { $conditional = '<'; }
            when(/\$lte/) { $conditional = '<='; }
            when(/\$gt/) { $conditional = '>'; }
            when(/\$gte/) { $conditional = '>='; }
        }

        if ( ref($value->{$f}) eq 'ARRAY' )
        {
            my $c = $self->create_filter_from_array($value, $f, $field);
            push( @where, $c ) if ( length($c) );
        }
        elsif ( ref($value->{$f}) eq 'HASH' )
        {
            my $c = $self->create_filter_from_hash($value, $f, $field);
            push( @where, $c ) if ( length($c) );
        }
        else {
            my $c = $self->create_filter_from_scalar($value->{$f}, $f, $field, $conditional);
            push( @where, $c ) if ( length($c) );
        }
    }

    return '(' . join(" $connect ", @where) . ')';
}


sub create_filter_from_array {
    my ($self, $value, $field, $parent_field) = @_;

    if ( defined( $field ) ) {
        $value = $value->{$field};
    }

    my @fields = @{ $value };

    return '' if ( @fields == 0 );

    my @where = ();
    my $connect = '';

    given( $field )
    {
        when(/\$nor/) { $connect = 'NOT OR'; $field = undef; }
        when(/\$or/) { $connect = 'OR'; $field = undef; }
        when(/\$and/) { $connect = 'AND'; $field = undef; }
        when(/\$in/) {
            return '(' . $parent_field . ' IN (' . join(",", @{ $value }) . '))';
        }
        when(/\$nin/) {
            return '(' . $parent_field . ' NOT IN (' . join(",", @{ $value }) . '))';
        }
    }

    # build up the search criteria
    for my $f ( @fields ) {
        my $criteria = '';

        if ( ref($f) eq 'ARRAY' )
        {
            my $c = $self->create_filter_from_array($f, $field);
            push( @where, $c ) if ( length($c) );
        }
        elsif ( ref($f) eq 'HASH' )
        {
            my $c = $self->create_filter_from_hash($f, $field);
            push( @where, $c ) if ( length($c) );
        }
    }

    return '(' . join(" $connect ", @where) . ')';
}


sub create_filter_from_scalar {
    my ($self, $value, $field, $parent_field, $conditional) = @_;

    $conditional //= '=';
    $field = $parent_field if ( $field =~ /^\$/ );

    if ( $value =~ m/[^\d]/ )
    {
        return $field . $conditional . $self->{__handle}->quote($value);
    }

    return $field . $conditional . $value;
}

1;
