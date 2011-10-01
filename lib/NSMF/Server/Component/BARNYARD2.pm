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
package NSMF::Server::Component::BARNYARD2;

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
use NSMF::Server;
use NSMF::Server::Driver;
use NSMF::Common::Logger;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

sub hello {
    $logger->debug("Hello World from BARNYARD2 server component!!");
    my $self = shift;
    $_->hello for $self->plugins;
}

sub node_max_eid_get
{
    my ($self, $node_id) = @_;

    my $db = NSMF::Server->database();

    my $max_eid = $db->custom("event", "event_id_max", {
        "node_id" => $node_id
    });

    return $max_eid;
}


sub process {
    my ($self, $data) = @_;

    if ( ! defined($data->{action}) ) {
        return undef;
    }

    given($data->{action})
    {
        when("node_max_eid_get") {
            my $max_eid = $self->node_max_eid_get($data->{parameters}{node_id});

            return $max_eid;
        }
        when("event_alert") {
            return $self->save($data->{parameters});
        }
    }

    return undef;
}

sub validate {
    my ($self, $event) = @_;

    my $db = NSMF::Server->database();

    # verify number of elements
    my $event_fields = @{ $event };

    if ( @{ $event } < 25 )
    {
        $logger->debug('Insufficient fields in EVENT line. Got ' . $event_fields . ' and expected 25.');
        return 0;
    }

    # verify duplicate in db
    my $dup = $db->search({
        event => {
            id => $event->[1]+0,
        }
    });

    # already exists confirm it's there already
    if ( @{ $dup } )
    {
        $logger->debug('Event already stored.');
        return 2;
    }

    return 1;
}

sub save {
    my ($self, $event) = @_;

    # validation the event data received
    my $validation = $self->validate( $event );

    my $event_id = $event->[1]+0;

    return 0 if ($validation == 0);
    return $event_id if ($validation == 2);

    my $db = NSMF::Server->database();
#2011-09-01 20:11:40 [D] {"params":{"parameters":["1","376631","21","2011-09-01 22:07:30.308857","1","30100000","1","Snort Alert [1:30100000:0]","3","not-suspicious","4","85.19.221.250","8","8.8.4.4","0","1","4","5","0","84","0","2","0","64","64399","","","","","","","","","","","","","","02E65F4E4FB6040008090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F202122232425262728292A2B2C2D2E2F3031323334353637"],"action":"event_alert"},"jsonrpc":"2.0","id":"33612","method":"post"}

    my $ret = $db->insert({
        event => {
            id => $event_id,
            timestamp => $event->[3],
            classification => 0,
            node_id => $event->[0]+0,
            net_version => $event->[10]+0,
            net_protocol => $event->[15]+0,
            net_src_ip => $event->[11],
            net_src_port => $event->[12]+0,
            net_dst_ip => $event->[13],
            net_dst_port => $event->[14]+0,
            sig_type => 1,
            sig_id => $event->[5]+0,
            sig_revision => $event->[6]+0,
            sig_message => $event->[7],
            sig_priority => $event->[8]+0,
            sig_category => $event->[9],
            meta => $event->[38],
            meta_u2_event_id => $event->[2]+0,
            meta_u2_filename => ''
        }
    });

    if( $ret )
    {
        return $event_id;
    }

    return -1;
}

1;
