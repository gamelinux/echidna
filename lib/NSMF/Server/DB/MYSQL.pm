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
use Module::Pluggable search_path => 'NSMF::Server::DB::MYSQL', sub_name => 'data_types', except => qr/Base/;

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
my @supported_types = ();
my $db_dsn;
my $db_handle;

sub instance {
    if ( ! defined($instance) )
    {
        $instance = bless({
            __settings => undef,
            __connection => undef,
            __version => undef,
            __handle => undef,
        }, __PACKAGE__);
    }

    return $instance;
}

sub create {
    my ($self, $settings) = @_;

    my @data_types = __PACKAGE__->data_types();

    $self->{__settings} = $settings;

    $self->connect($settings);

    # load establish call backs
    for my $data_type_path ( @data_types )
    {
        my $data_type;
        $data_type = lc($1) if ( $data_type_path =~ m/::(\w+)$/ );

        eval "use $data_type_path";

        if ( $@ ) {
            die { 'status' => 'error', 'message' => 'Unable to load callbacks for ' . $data_type . '(' . $@ .')' };
        }

        $logger->debug('  Loading ' . $data_type . ' callbacks.');
        $type_map->{$data_type} = $data_type_path->new();

        if ( ! $type_map->{$data_type}->create($self->{__handle}) )
        {
            $logger->error('    Unable to create persistant storage.');
        }

        if ( ! $type_map->{$data_type}->validate() )
        {
            $logger->error('    The storage integrity is corrupt or out of date.');
        }
    }

    @supported_types = keys(%{ $type_map });

    # check the database integrity (build if required)


    # determine version
    my $version = $self->{__handle}->selectall_arrayref('SHOW VARIABLES WHERE variable_name="version"');
    $version //= "0.0.0-unknown";

    ($self->{__version}{major}, $self->{__version}{minor}, $self->{__version}{revision}) = split(/[\.\-]/, $version);
}


sub connect {
    my ( $self, $settings ) = @_;

    if ( ! defined($self->{__connection}) ) {
        my $host = $settings->{host} // 'localhost';
        my $port = $settings->{port} // '3306';
        my $name = $settings->{name} // $logger->fatal('No database name provided.');

        # establish connection
        $self->{__connection} = "dbi:mysql:$name:$host:$port";
    }

    my $user = $settings->{user} // $logger->fatal('No database user provided.');
    my $pass = $settings->{pass} // $logger->fatal('No database password provided.');

    $self->{__handle} = DBI->connect($self->{__connection}, $user, $pass, { RaiseError => 0, PrintError => 1});

    if ( ! $self->{__handle} ) {
        $logger->fatal('Unable to connect to the database.');
    }
}


sub server_version_get {
    my $self = shift;

    return $self->{__version};
}

#
# DATA MANIPULATION AND QUERY
#


sub insert {
    my ($self, $data) = @_;

    if ( ! ref($data) eq 'HASH' )
    {
        $logger->warn('Ignoring entry due to uknown format');
        return 0;
    }

    my ($type, $batch) = each(%{ $data });

    if ( ! ($type ~~ @supported_types) )
    {
        $logger->warn('No callback to handle type: ' . $type, @supported_types);
        return 0;
    }

    $batch = [ $batch ] if ( ref($batch) ne 'ARRAY' );

    # start transaction

    my $ret = 0;

    for my $entry ( @{ $batch } )
    {
        if ( ref($entry) ne 'HASH' )
        {
            $logger->warn('Ignoring entry due to unknown format: ' . ref($entry));
            next;
        }

        $logger->debug('Adding entry');

        eval {
            $ret |= $type_map->{$type}->insert($entry);
        };

        if ( $@ ) {
            $logger->warn('DB ERROR: ' . $DBI::err);

            # database has disappeared, let's reconnect
            if( $DBI::err == 2006 ) {
                $self->connect();
                redo;
            }
        }
    }

    # end transaction

    return $ret;
}

sub search {
    my ($self, $filter) = @_;

    # ensure the filter is provided
    if ( ref($filter) ne 'HASH' && keys( %{ $filter }) == 1)
    {
        $logger->warn('Ignoring filter due to unknown format: ' . ref($filter));
        return [];
    }

    my $type = ( keys( %{ $filter } ) )[0];
    $filter = $filter->{$type};

    # search if our type is supported
    if ( $type ~~ @supported_types )
    {
        # remove the type from the filter
        my $ret = undef;

        eval {
            $ret = $type_map->{$type}->search($filter);
        };

        if ( $@ ) {
            $logger->warn('DB ERROR: ' . $DBI::err);

            # database has disappeared, let's reconnect
            if( $DBI::err == 2006 ) {
                $self->connect();

                eval {
                    $ret = $type_map->{$type}->search($filter);
                };
            }
        }

        return $ret;
    }

    $logger->warn('Ignoring filter due to unsupported type: ' . $type, @supported_types);
}

sub custom {
    my ($self, $type, $method, $filter) = @_;

    # search if our type is supported
    if ( $type ~~ @supported_types )
    {
        # remove the type from the filter
        return $type_map->{$type}->custom($method, $filter);
    }

    $logger->warn('Ignoring filter due to unsupported type: ' . $type, @supported_types);
}

sub update {
    my ($self, $data, $filter) = @_;

}

sub delete {
    my ($self, $filter) = @_;

    # ensure the filter is provided
    if ( ref($filter) ne 'HASH' && keys( %{ $filter }) == 1)
    {
        $logger->warn('Ignoring filter due to unknown format: ' . ref($filter));
        return [];
    }

    my $type = ( keys( %{ $filter } ) )[0];
    $filter = $filter->{$type};

    # search if our type is supported
    if ( $type ~~ @supported_types )
    {
        # remove the type from the filter
        my $ret = undef;

        eval {
            $ret = $type_map->{$type}->delete($filter);
        };

        if ( $@ ) {
            $logger->warn('DB ERROR: ' . $DBI::err);

            # database has disappeared, let's reconnect
            if( $DBI::err == 2006 ) {
                $self->connect();

                eval {
                    $ret = $type_map->{$type}->delete($filter);
                };
            }
        }

        return $ret;
    }

    $logger->warn('Ignoring filter due to unsupported type: ' . $type, @supported_types);
}

1;
