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
package NSMF::Server::Component::CXTRACKER;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Server::Component);

#
# PERL INCLUDES
#
use Module::Pluggable require => 1;

#
# NSMF INCLUDES
#
use NSMF::Server::Driver;
use NSMF::Common::Logger;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

__PACKAGE__->install_properties({
    columns => [
        'id', 
        'session_id', 
        'start_time',
        'end_time',
        'duration',
        'ip_proto',
        'ip_version',
        'src_ip',
        'src_port',
        'dst_ip',
        'dst_port',
        'src_pkts',
        'src_bytes',
        'dst_pkts',
        'dst_bytes',
        'src_flags',
        'dst_flags',
    ],
    datasource => 'nsmf_cxtracker',
    primary_key => [ 'id', 'session_id'],
    driver => NSMF::Server::Driver->driver(),
});


sub hello {
    $logger->debug("Hello World from CXTRACKER Module!!");
    my $self = shift;
    $_->hello for $self->plugins;
}

sub validate {
    my ($self, $session) = @_;

    $session =~ /^\d{19}/;

    if ( ! $session) {
        $logger->warn("[*] Error: Not valid session start format in");
    }

    my @elements = split /\|/, $session;
    
    # verify number of elements
    unless(@elements == 15) {
        die { status => 'errpr', message => 'Invalid number of elements' };
    }

    # verify duplicate in db
    my $class = ref $self;
    if ($class->search({ session_id => $elements[0] })->next) {
        die { status => 'error', message => 'Duplicated Session' };
    }
   
    1;
 
}

sub save {
    my ($self, $session) = @_;

    # validation
    eval {
        $self->validate( $session );
    };

    if (ref $@) {
        $logger->error("  ->  Session validation failed: " .$@->{message});;
        return;
    }

    my @tokens = split /\|/, $session;

    $self->session_id( $tokens[0] );
    $self->start_time( $tokens[1] );
    $self->end_time( $tokens[2] );
    $self->duration( $tokens[3] );
    $self->ip_proto( $tokens[4] );
    $self->src_ip( $tokens[5] );
    $self->src_port( $tokens[6] );
    $self->dst_ip( $tokens[7] );
    $self->dst_port( $tokens[8] );
    $self->src_pkts( $tokens[9] );
    $self->src_bytes( $tokens[10] );
    $self->dst_pkts( $tokens[11] );
    $self->dst_bytes( $tokens[12] );
    $self->src_flags( $tokens[13] );
    $self->dst_flags( $tokens[14] );
    $self->ip_version( 4 );

    # if everything is ok
    if ($self->SUPER::save) {
        return 1;
    } 
        
    return;
}



1;
