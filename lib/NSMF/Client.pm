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
package NSMF::Client;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Data::Dumper;
use File::Spec;
use Module::Pluggable search_path => 'NSMF::Client::Component', sub_name => 'modules';
use Module::Pluggable search_path => 'NSMF::Client::Proto', sub_name => 'protocols';

#
# NSMF INCLUDES
#
use NSMF::Common::Registry;
use NSMF::Client::ProtoMngr;
use NSMF::Client::ConfigMngr;

#
# GLOBALS
#
our $BASE_PATH;

my $instance;

sub new {
    if ( ! defined($instance) ) {

        my $config = NSMF::Common::Registry->get('config');
        my $logger = NSMF::Common::Registry->get('log');

        my $proto;

        eval {
            $proto = NSMF::Client::ProtoMngr->create($config->protocol());
        };

        if ( $@ ) {
            $logger->fatal(Dumper($@));
        }

        $instance = bless {
            __config      => $config,
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

1;
