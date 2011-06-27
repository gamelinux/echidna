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
# DATA STORE CREATION AND VALIDATION
#

sub create {
    $logger->warn('Base create method needs to be overridden.');

    return 0;
}

sub validate {
    $logger->warn('Base validate method needs to be overridden.');

    return 0;
}

#
# DATA OBJECT QUERY AND MANIPULATION
#

sub insert {
    $logger->warn('Base insert method needs to be overridden.');
}

sub search {
    $logger->warn('Base search method needs to be overridden.');
}

sub delete {
    $logger->warn('Base delete method needs to be overridden.');
}

1;
