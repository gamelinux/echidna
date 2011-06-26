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
package NSMF::Server::DB::MYSQL;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Data::Dumper;
use DBI;
use DBD::mysql;
use Module::Pluggable search_path => 'NSMF::Server::DB::MYSQL', sub_name => 'types';

#
# NSMF INCLUDES
#
use NSMF::Common::Logger;

#
# GLOBALS
#
my $instance;
my $type_map = {};
my $logger = NSMF::Common::Logger->new();
my @provides = ('event', 'session');
my $db_dsn;
my $db_handle;

sub instance {
    if ( ! defined($instance) )
    {
        $instance = bless({}, __PACKAGE__);

        load();
    }

    return $instance;
}

sub load {
    my $self = shift;
    my @types = __PACKAGE__->types();

    # establish call backs
    for my $type ( @provides )
    {
        my $type_path = __PACKAGE__ . '::' . ucfirst($type);
       
        if ( $type_path ~~ @types ) {
            eval "use $type_path";
  
            if ( $@ ) {
                die { 'status' => 'error', 'message' => 'Unable to load callbacks for ' . $type . '(' . $@ .')' };
            }

            $logger->debug('  Loading ' . $type . ' callbacks.');
            $type_map->{type} = $type_path;
        }
    }

    # establish connection
    $db_dsn = "dbi:mysql:$name:$host:$port";

    eval {
        $db_handle = DBI->connect($db_dsn, $user, $pass, { RaiseError => 1, PrintError => 0});
    };

    if ( $@ ) {
        $logger->fatal('Unable to connect to the database.');
    }
}

sub insert {
    my ($self, $data) = @_;

    my $batch = [];

    $batch = [ $data ] if ( ref($data) ne 'ARRAY' );

    for my $entry ( @{ $batch } )
    {
        if ( ref($entry) ne 'HASH' )
        {
            $logger->warn('Ignoring entry due to unknown format: ' . ref($entry));
            next;
        }
        
        if ( $entry->{type} ~~ keys(%{ $type_map }) ) 
        {
            $logger->debug('Adding entry');
        }
        else
        {
            $logger->warn('No callback to handle type: ' . $entry->{type});
        }

    }
}

sub search {
    my ($self, $data) = @_;

}

sub delete {
    my ($self, $data) = @_;

}


sub mysql_command {

}

1;
