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
package NSMF::Server::Component;

use warnings;
use strict;
use v5.10;

use base qw(Exporter);

use Carp;

#
# NSMF INCLUDES
#
use NSMF::Common::Registry;

#
# GLOBALS
#
my $logger = NSMF::Common::Registry->get('log') 
    // carp 'Got an empty config object from Registry';

#
# MEMBERS
#

sub new {
    my $class = shift;

    my $obj = bless {
    }, $class;

    return $obj->init(@_);
}

sub init {
    my ($self) = @_;

    return $self;
}

sub get_registered_methods {
    my ($self) = @_;

    $logger->warn('Base GET_REGISTERED_METHODS needs to be overridden.');

    return [];
}

sub logger {
    return NSMF::Common::Registry->get('log');
}

1;
