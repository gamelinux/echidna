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
package NSMF::Common::Util;

use warnings;
use strict;
use v5.10;

use base qw(Exporter);

#
# PERL INCLUDES
#
use Data::Dumper;
use Carp qw(croak);

#
# GLOBALS
#
our @EXPORT = qw(
    trim
    defined_args 
);

our $VERSION = '0.1';

sub trim {
    my ($msg) = @_;
    $msg =~ s/^\s+//g;
    $msg =~ s/\s+$//g;
    return $msg;
}

sub defined_args {
    my @args = @_;

    return unless @args;

    for my $arg (@args) {
        return if ( ! defined($arg) );
    }

    return 1;
}

#
# DEPRECATED
#
sub verify_node {
    my ($self) = @_;
    return unless ref($self) ~~ /NSMF::Node/;
}

sub check_config {
    my $config = shift;
    my @KEYS = qw(id nodename netgroup secret server port);

    foreach my $key (@KEYS) {
        not_defined("$key") unless grep $_ eq $key, @KEYS and defined $config->{$key};
    }

    return 1;
}



1;
