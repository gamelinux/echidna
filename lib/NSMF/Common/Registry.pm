#
# This file is part of the NSM framework
#
# Copyright (C) 2010-2012, Edward Fjellskål <edwardfjellskaal@gmail.com>
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
package NSMF::Common::Registry;

use strict;
use v5.10;

use Carp;
use NSMF::Common::Util;

#
# GLOBALS
#
our $VERSION = '0.1';

#
# NSMF INCLUDES
#

my $instance;
sub new {
    __PACKAGE__->instance();
}

sub instance {
    my ($class, $args) = @_;

    unless (defined $instance) {
        $instance =  bless {}, __PACKAGE__;
    }

    return $instance;
}

sub get {
    my ($class, $key) = @_;

    __PACKAGE__->instance();

    unless ($key ~~ /^[a-z]+$/i) {
        carp "Bad get key on " .__PACKAGE__;
        return;
    }

    if (exists $instance->{$key}) {
        return $instance->{$key};
    }
}

sub set {
    my ($class, $key, $value, $force) = @_;

    __PACKAGE__->instance();

    unless (defined_args($key, $value)) {
        carp "Undefined key or value on " .__PACKAGE__;
        return;
    }

    unless ($key ~~ /^[a-z]+$/i) {
        carp "Bad set key on " .__PACKAGE__;
        return;
    }

    $instance->{$key} = $value;
}

sub data {
    __PACKAGE__->instance();

    return $instance;
}

1;
