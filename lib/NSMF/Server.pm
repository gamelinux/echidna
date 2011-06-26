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
package NSMF::Server;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Data::Dumper;
use File::Spec;
use Module::Pluggable search_path => 'NSMF::Server::Component', sub_name => 'modules';
use Module::Pluggable search_path => 'NSMF::Server::Worker', sub_name => 'workers';
use Module::Pluggable search_path => 'NSMF::Server::Proto', sub_name => 'protocols';
use Module::Pluggable search_path => 'NSMF::Server::DB', sub_name => 'databases';

#
# NSMF INCLUDES
#
use NSMF::Common::Logger;
use NSMF::Server::ConfigMngr;
use NSMF::Server::DBMngr;
use NSMF::Server::ProtoMngr;

#
# GLOBALS
#
my $instance;

sub new {
    if ( ! defined($instance) ) {

        my $config_path = File::Spec->catfile('../etc', 'server.yaml');

        if ( ! -f -r $config_path) {
            die 'Server Configuration File Not Found';
        }

        my $config = NSMF::Server::ConfigMngr::instance();
        $config->load($config_path);

        my $logger = NSMF::Common::Logger->new();
        $logger->verbosity(5) if $config->debug_on;

        my $proto;
        my $database;

        eval {
            $database = NSMF::Server::DBMngr->create($config->database());
            $proto = NSMF::Server::ProtoMngr->create($config->protocol());
        };

        if ( ref($@) )
        {
            $logger->fatal(Dumper($@));
        }

        $instance = bless {
            __config_path => $config_path,
            __config      => $config,
            __database    => $database,
            __proto       => $proto, 
        }, __PACKAGE__;
    }

    return $instance;
}

# get method for config singleton object
sub config {
    my ($self) = @_;

    return if ( ref($instance) ne __PACKAGE__ );

    return $instance->{__config} // die { status => 'error', message => 'No Configuration File Enabled' }; 
}

# get method for proto singleton object
sub proto {
    my ($self) = @_;

    return if ( ref($instance) ne __PACKAGE__ );

    return $instance->{__proto} // die { status => 'error', message => 'No Protocol Enabled' };
}

# get method for database singleton object
sub database {
    my ($self) = @_;

    return if ( ref($instance) ne __PACKAGE__ );

    return $instance->{__database} // die { status => 'error', message => 'No Database Enabled' };
}

1;
