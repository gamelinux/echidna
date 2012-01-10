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
    my ($self, $node, $json) = @_;

    my $sessions = $json->{params};

    return -1 if ( ! ref($sessions) eq 'ARRAY' );

    my $saved = [];

    for my $s ( @{ $sessions } ) {

        my @session = split(/\|/, $s);

        # validation the event data received
        my $validation = $self->validate( \@session );

        my $session_id = $session[0]+0;

        return 0 if ($validation == 0);
        return $session_id if ($validation == 2);

        my $db = NSMF::Server->database();

#2011-09-01 20:11:40 [D] {"params":{"parameters":["1","376631","21","2011-09-01 22:07:30.308857","1","30100000","1","Snort Alert [1:30100000:0]","3","not-suspicious","4","85.19.221.250","8","8.8.4.4","0","1","4","5","0","84","0","2","0","64","64399","","","","","","","","","","","","","","02E65F4E4FB6040008090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F3031323334353637"],"action":"event_alert"},"jsonrpc":"2.0","id":"33612","method":"post"}

        my $ret = $db->insert({
            session => {
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
            }
        });

        # TODO: deal with batches better
        # should we bail on single error, or report only id's that failed
        if( $ret )
        {
            push( @{ $saved }, $session_id );
        }
    };

    return $saved;
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
    my $dup = $db->search({
        session => {
            id => $session->[0],
        }
    });

    if ( @{ $dup } ) {
        $logger->debug('Session already stored.');
        return 2;
    }

    return 1;
}


1;
