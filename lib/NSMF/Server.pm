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
use Module::Pluggable search_path => 'NSMF::Server::Proto::Node', sub_name => 'node_protocols';
use Module::Pluggable search_path => 'NSMF::Server::Proto::Client', sub_name => 'client_protocols';
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
my $logger = NSMF::Common::Logger->new();

sub new {
    if ( ! defined($instance) ) {

        my $config_path = File::Spec->catfile('../etc', 'server.yaml');

        if ( ! -f -r $config_path) {
            die 'Server Configuration File Not Found';
        }

        my $config = NSMF::Server::ConfigMngr::instance();
        $config->load($config_path);

        my $node_proto;
        my $client_proto;
        my $database;

        eval {
            $database = NSMF::Server::DBMngr->create($config->database());
            $node_proto = NSMF::Server::ProtoMngr->create('node', $config->protocol('node'));
            $client_proto = NSMF::Server::ProtoMngr->create('client', $config->protocol('client'));
        };

        if ( $@ )
        {
            $logger->fatal(Dumper($@));
        }

        $instance = bless {
            __config_path => $config_path,
            __config      => $config,
            __database    => $database,
            __proto       => {
                node    => $node_proto,
                client  => $client_proto,
            }
        }, __PACKAGE__;
    }

    return $instance;
}

# get method for config singleton object
sub config {
    my ($self) = @_;

    return if ( ref($instance) ne __PACKAGE__ );

    return $instance->{__config} // die { status => 'error', message => 'No configuration file enabled!' }; 
}

# get method for proto singleton object
sub proto {
    my ($self, $type) = @_;

    return if ( ref($instance) ne __PACKAGE__ );

    if ( defined($type) ) {
        return $instance->{__proto}{$type};
    }

    return $instance->{__proto};
}

# get method for database singleton object
sub database {
    my ($self) = @_;

    return if ( ref($instance) ne __PACKAGE__ );

    return $instance->{__database} // die { status => 'error', message => 'No database defined.' };
}

1;
