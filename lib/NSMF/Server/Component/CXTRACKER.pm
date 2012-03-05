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
package NSMF::Server::Component::CXTRACKER;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Server::Component);

#
# PERL INCLUDES
#
use Module::Pluggable require => 1;
use Carp;

#
# NSMF INCLUDES
#
use NSMF::Model::Session;
use NSMF::Server;
use NSMF::Common::Registry;

#
# GLOBALS
#
my $logger = NSMF::Common::Registry->get('log')
    // carp 'Got an empty config object from Registry';

sub get_registered_methods {
    my ($self) = @_;

    return [
        {
            method => 'cxtracker.save',
            acl    => 0,
            func   => sub{ $self->save(@_); }
        }
    ];
}

sub save {
    my ($self, $node, $json, $cb_success, $cb_error) = @_;

    my $sessions = $json->{params};

    if ( ! ref($sessions) eq 'ARRAY' ) {
        return $cb_error->($json, -1);
    }

    my $saved = [];
    my $db = NSMF::Server->database();

    for my $s ( @{ $sessions } ) {

        my @session = split(/\|/, $s);

        # validation the event data received
        my $validation = $self->validate( \@session );

        my $session_id = $session[0]+0;

#        return $cb->error(0) if ($validation == 0);
#        return $cb->error($session_id) if ($validation == 2);

        my $session = NSMF::Model::Session->new({
            id => $session[0],
            timestamp => 0,
            time_start => $session[1],
            time_end   => $session[2],
            time_duration => $session[3],
            node_id => $node->{details}{id},
            net_version => 4,
            net_protocol => $session[4],
            net_src_ip   => $session[5],
            net_src_port => $session[6],
            net_src_total_packets => $session[9],
            net_src_total_bytes => $session[10],
            net_src_flags => $session[13],
            net_dst_ip   => $session[7],
            net_dst_port => $session[8],
            net_dst_total_packets => $session[11],
            net_dst_total_bytes => $session[12],
            net_dst_flags => $session[14],
            data_filename_start => $session[15],
            data_offset_start => $session[16],
            data_filename_end => $session[17],
            data_offset_end => $session[18],
            meta_cxt_id => $session[0],
        });

        $db->insert(session => $session);

        # TODO: deal with batches better
        # should we bail on single error, or report only id's that failed
        push( @{ $saved }, $session_id );
    };

    # 
    return $cb_success->($json, $saved);
}

sub validate {
    my ($self, $session) = @_;

    my $db = NSMF::Server->database();

    # verify number of elements
    my $session_fields = @{ $session };

    if ( @{ $session } < 19 )
    {
        $logger->debug('Insufficient fields in SESSION line. Got ' . $session_fields . ' and expected 19.');
        return 0;
    }

    # verify duplicate in db
#    my $dup = $db->search(session => {
#        id => $session->[0],
#    });

#    $logger->debug($dup);

#    if ( @{ $dup } ) {
#        $logger->debug('Session already stored.');
#        return 2;
#    }

    return 1;
}


1;
