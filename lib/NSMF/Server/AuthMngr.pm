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
use NSMF::Model::Agent;
use NSMF::Model::Node;

#
# GLOBALS
#
my $logger = NSMF::Common::Registry->get('log') 
    // carp 'Got an empty config object from Registry';

sub authenticate_agent {
    my ($self, $name, $key, $cb_success, $cb_error) = @_;

    my $db = NSMF::Server->database();

    $db->search(agent => { name => $name }, sub {
        my $agent = shift;

        if ( @{ $agent } == 1 &&
             $agent->[0]->{'password'} eq $key ) {
            $cb_success->( $agent->[0] );
        }
        else {
            $cb_error->( {status => 'error', message => 'Unknown agent or secret.'} );
        }
    });
}

sub authenticate_node {
    my ($self, $name, $type, $cb_success, $cb_error) = @_;

    my $db = NSMF::Server->database();

    $db->search(node => {
        name => $name,
        type => $type,
    }, sub {
        my $node = shift;

        if ( @{ $node } == 1 ) {
            $cb_success->( $node->[0] );
        }
        else {
            $cb_error->( {status => 'error', message => 'Unknown node.'} );
        }
    });

}

sub authenticate_client {
    my ($self, $name, $key, $cb_success, $cb_error) = @_;

    my $db = NSMF::Server->database();

    $db->search(client => { name => $name }, sub {
        my $client = shift;

        if ( @{ $client } == 1 &&
            $client->[0]->password() eq $key ) {
            $cb_success->( $client->[0] );
        }
        else {
          $cb_error->( { status => 'error', message => 'Unkown client or secret.' } );
        }
    });
}



1;
