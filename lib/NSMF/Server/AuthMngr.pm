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
package NSMF::Server::AuthMngr;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Carp;

#
# NSMF INCLUDES
#
use NSMF::Server;
use NSMF::Common::Registry;

#
# GLOBALS
#
my $logger = NSMF::Common::Registry->get('log') 
    // carp 'Got an empty config object from Registry';

sub authenticate_agent {
    my ($self, $name, $key) = @_;

    my $database = NSMF::Server->database();

    my $agent = $database->search({
        agent => {
            name => $name,
            #version => [gt, 1],
        },
    });

    if ( @{ $agent } == 1 &&
         $agent->[0]->{password} eq $key ) {
        return $agent->[0];
    }
    else {
        croak {status => 'error', message => 'Unknown agent or secret.'};
    }
}

sub authenticate_node {
    my ($self, $name, $type) = @_;

    my $database = NSMF::Server->database();

    my $node = $database->search({
        node => {
            name => $name,
            type => $type,
            #version => [gt, 1],
        },
    });

    if ( @{ $node } == 1 ) {
        return $node->[0];
    }
    else {
        croak {status => 'error', message => 'Unknown node.'};
    }
}

sub authenticate_client {
    my ($self, $name, $key) = @_;

    my $database = NSMF::Server->database();

    my $client = $database->search({
        client => {
            name => $name,
            #version => [gt, 1],
        },
    });

    if ( @{ $client } == 1 &&
         $client->[0]->{password} eq $key ) {
      return $client->[0];
    }
    else {
      croak { status => 'error', message => 'Unkown client or secret.' };
    }
}



1;
