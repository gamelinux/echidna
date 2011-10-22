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
use Carp;
use File::Spec;
use Data::Dumper;
use Module::Pluggable search_path => 'NSMF::Server::Component', sub_name => 'modules';
use Module::Pluggable search_path => 'NSMF::Server::Worker', sub_name => 'workers';
use Module::Pluggable search_path => 'NSMF::Server::Proto::Node', sub_name => 'node_protocols';
use Module::Pluggable search_path => 'NSMF::Server::Proto::Client', sub_name => 'client_protocols';
use Module::Pluggable search_path => 'NSMF::Server::DB', sub_name => 'databases';

#
# NSMF INCLUDES
#
use NSMF::Common::Registry;

use NSMF::Server::DBMngr;
use NSMF::Server::ProtoMngr;
use NSMF::Server::ConfigMngr;

#
# GLOBALS
#
our $BASE_PATH;

my $singleton;

#
# CONSTANTS
#
my $VERSION = {
  major     => 0,
  minor     => 1,
  revision  => 0,
  build     => 1,
};

sub new {
    return instance();
}

sub instance {
    if ( ! defined($singleton) ) {

        # registry needs to be set from the beginning
        my $registry = NSMF::Common::Registry->new();

        # set logger in the registry
        my $logger = $registry->get('log');

        my $config_path = File::Spec->catfile($BASE_PATH, 'etc', 'server.yaml');

        if ( ! -f -r $config_path) {
            croak 'Server Configuration File Not Found';
        }

        my $config = NSMF::Server::ConfigMngr::instance();
        $config->load($config_path);
        NSMF::Common::Registry->set( config => $config );

        my ($node_proto, $client_proto, $database);

        eval {
            $database = NSMF::Server::DBMngr->create($config->database());
            $node_proto = NSMF::Server::ProtoMngr->create('node', $config->protocol('node'));
            $client_proto = NSMF::Server::ProtoMngr->create('client', $config->protocol('client'));

        }; 
        
        if ( $@ ) {
            $logger->fatal(Dumper($@));
        }

        # store them on the registry
        $registry->set( config => $config );
        $registry->set( db => $database );

        $singleton = bless {
            __config_path => $config_path,
            __config      => $config,
            __database    => $database,
            __started     => time(),
            __version     => $VERSION,
            __proto       => {
                node    => $node_proto,
                client  => $client_proto,
            },
            __clients     => {},
            __nodes       => {}
        }, __PACKAGE__;
    }

    return $singleton;
}

# get method for config singleton object
sub config {
    my ($self) = @_;

    return if ( ref($singleton) ne __PACKAGE__ );

    return $singleton->{__config} // die { status => 'error', message => 'No configuration file enabled!' }; 
}

# get method for proto singleton object
sub proto {
    my ($self, $type) = @_;

    return if ( ref($singleton) ne __PACKAGE__ );

    if ( defined($type) ) {
        return $singleton->{__proto}{$type};
    }

    return $singleton->{__proto};
}

# get method for database singleton object
sub database {
    my ($self) = @_;

    return if ( ref($singleton) ne __PACKAGE__ );

    return $singleton->{__database} // die { status => 'error', message => 'No database defined.' };
}

sub clients {
    my ($self) = @_;

    return if ( ref($singleton) ne __PACKAGE__ );

    return $singleton->{__clients} // {};
}


sub nodes {
    my ($self) = @_;

    return if ( ref($singleton) ne __PACKAGE__ );

    return $singleton->{__nodes} // {};
}


1;
