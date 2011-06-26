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
package NSMF::Server::ConfigMngr;
    
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
our $debug;
my $instance;
my ($server, $settings);

sub instance {
    if ( ! defined($instance) ) {
        $instance = bless {
            name     => 'NSMFServer',
            server   => '127.0.0.1',
            port     => 10101,
            settings => {},
            modules  => [],
        }, __PACKAGE__;
    }

    return $instance;
}

sub load {
    my ($self, $file) = @_;

    return if ( ref($self) ne __PACKAGE__ );

    __PACKAGE__->instance();

    my $yaml = YAML::Tiny->read($file);
    croak 'Could not parse configuration file.' unless $yaml;

    $self->{server}   = $yaml->[0]->{server}   // '0.0.0.0';
    $self->{port}     = $yaml->[0]->{port}     // 0;
    $self->{settings} = $yaml->[0]->{settings} // {};
    $self->{modules}  = $yaml->[0]->{modules}  // [];
    map { $_ = lc $_ } @{ $self->{modules} };
    $debug = $yaml->[0]->{settings}->{debug}   // 0;
    
    $instance = $self;

    return $instance;
}

sub name {
    return $instance->{name} // 'NSMFServer';
}

sub address {
    return $instance->{server} // croak '[!] No server defined.';
}

sub port {
    return $instance->{port} // croak '[!] No port defined.';
}

sub modules {
    my $self = shift;
    return unless ref $self eq __PACKAGE__;

    return $instance->{modules};
}

sub database {
    my $self = shift;
    return unless ref $self eq __PACKAGE__;

    return $instance->{settings}->{database};
}

sub protocol {
    my $self = shift;
    return unless ref $self eq __PACKAGE__;

    return $instance->{settings}->{protocol};
}

sub debug_on {
    my $self = shift;
    return unless ref $self eq __PACKAGE__;

    return $instance->{settings}->{debug};
}

1;
