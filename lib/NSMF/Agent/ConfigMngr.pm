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
package NSMF::Agent::ConfigMngr;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Carp qw(croak);
use Digest::SHA qw(sha256_hex);
use YAML::Tiny;

#
# NSMF INCLUDES
#
use NSMF::Common::Util;

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

    carp('Multiple configuration pages found. Using the first.') if ( $pages > 1 );

    # only use the first page
    $self->{config}   = $yaml->[0];

    # configure defaults
    $self->{config}{node}{agent}            //= 'unknown';
    $self->{config}{node}{name}             //= 'unknown';
    $self->{config}{node}{netgroup}         //= 'default';
    $self->{config}{node}{secret}           //= '';

    # let's ensure we store the secret in memory in hashed form
    $self->{config}{node}{secret} = sha256_hex($self->{config}{node}{secret});

    $self->{config}{server}{host}           //= 'localhost';
    $self->{config}{server}{port}           //= 10101;

    $self->{config}{protocol}               //= 'json';

    $self->{config}{modules}                //= [];
    map { $_ = lc $_ } @{ $self->{config}{modules} };

    $instance = $self;

    return $instance;
}

sub agent {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{node}{agent} // croak('[!] No agent name defined.');
}

sub name {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{node}{name} // croak('[!] No node name defined.');
}

sub host {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{server}{host} // croak('[!] No server defined.');
}

sub port {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{server}{port} // croak('[!] No port defined.');
}

sub netgroup {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{node}{netgroup} // croak('[!] No netgroup defined.');
}

sub secret {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{node}{secret} // croak('[!] No secret defined.');
}

sub protocol {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{protocol} // croak('[!] No protocol defined.');
}

sub settings {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{settings} // croak('[!] No settings defined.');
}

sub logging {
    my $self = shift;
    return if ( ref($self) ne __PACKAGE__ );

    return $instance->{config}{log};
}

1;
