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
package NSMF::Agent::Config;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Carp qw(croak);
use YAML::Tiny;

#
# NSMF INCLUDES
#
use NSMF::Common::Logger;
use NSMF::Common::Util;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

sub load {
    my ($file) = @_;
    my $config;

    croak 'Error opening configuration file. Check read access.' unless ( -e -r $file);

    given($file){
        when(/^.+\.yaml$/) {
            $config = load_yaml($file);
        }
        when(/^.+\.conf$/) {
            $config = load_config($file);
        }
        default: {
            $config = load_yaml($file);
        }
    }

    return $config // croak "Could not parse configuration file.";
}

sub load_yaml {
    my ($file) = @_;
    
    my $yaml = YAML::Tiny->read($file);

    my $server = $yaml->[0]->{server};
    my $node   = $yaml->[0]->{node};
    my $settings = $yaml->[0]->{settings};
  
    return unless defined_args($server, $node);
  
    # Server Checking

    # Node Checking   
    
    # Other Checking

    return {
        agent     => $node->{agent},
        nodename  => $node->{nodename},
        netgroup  => $node->{netgroup},
        secret    => $node->{secret},
        server    => $server->{server},
        port      => $server->{port},
        settings  => $settings,
    };
}

sub load_config {
    my ($file) = @_;

    my $config = {};
    if(not -r "$file"){
        warn "[W] Config '$file' not readable\n";
        return $config;
    }
    open(my $FH, "<",$file) or croak "[E] Could not open '$file': $!";
    while (my $line = <$FH>) {
        chomp($line);
        $line =~ s/\#.*//;
        next unless($line); # empty line
        # EXAMPLE=/something/that/is/string/repesented
        if (my ($key, $value) = ($line =~ m/(\w+)\s*=\s*(.*)$/)) {
           warn "[W] Read keys and values from config: $key:$value\n" if $NSMF::DEBUG > 0;
           $config->{$key} = $value;
        }else {
          croak "[E] Not valid configfile format in: '$file'";
        }
    }
    close $FH;
    return $config;
}

1;

=head2 load 

Public interface for automatic file configuration reading.

=cut

=head2 load_config

Reads the configuration file and loads variables.
Takes a config file and $NSMF::DEBUG as input, and returns a hash of config options.

=head2 load_yaml

Raed the configuration file in yaml format and loads variables.
=cut


