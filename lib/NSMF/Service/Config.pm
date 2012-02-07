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
package NSMF::Service::Config;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Carp;
use YAML::Tiny;

#
# GLOBALS
#
my $instance;

sub instance {
    if ( ! defined($instance) ) {

        $instance = bless {
            config  => {},
        }, __PACKAGE__;
    }

    return $instance;
}

sub load {
    my ($class, $file) = @_;

    my $self;
    if (ref $class eq __PACKAGE__) {
        $self = $class;
    } else {
        $self = __PACKAGE__->instance();
    }

    my $yaml = YAML::Tiny->read($file);

    croak 'Could not parse configuration file.' if ( ! defined($yaml) );

    # determine number of pages
    my $pages = @{ $yaml };

    croak 'No configuration page(s) available.' if ( $pages == 0 );

    carp('Multiple configuration pages found. Using the first') if ( $pages > 1 );

    # only use the first page
    $self->{config}   = $yaml->[0];

    # configure defaults
    $self->{config}{name}                   //= 'NSMF Server';

    $self->{config}{network}{node}{host}    //= 'localhost';
    $self->{config}{network}{node}{port}    //= 10101;
    $self->{config}{network}{client}{host}  //= 'localhost';
    $self->{config}{network}{client}{port}  //= 10201;

    $self->{config}{protocol}{node}         //= 'json';
    $self->{config}{protocol}{client}       //= 'json';

    $self->{config}{modules}                //= [];
    map { $_ = lc $_ } @{ $self->{config}{modules} };

    $instance = $self;

    return $instance;
}

sub name {
    return $instance->{config}{name} // 'NSMF Server';
}

sub node_host {
    return $instance->{config}{network}{node}{host} // croak '[!] No node network host defined.';
}

sub node_port {
    return $instance->{config}{network}{node}{port} // croak '[!] No node network port defined.';
}

sub client_host {
    return $instance->{config}{network}{client}{host} // croak '[!] No client network host defined.';
}

sub client_port {
    return $instance->{config}{network}{client}{port} // croak '[!] No client network port defined.';
}

sub modules {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{modules};
}

sub database {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{database};
}

sub protocol {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    my $type = shift;

    if ( defined($type) ) {
        return $instance->{config}{protocol}{$type};
    }

    return $instance->{config}{protocol};
}

1;
