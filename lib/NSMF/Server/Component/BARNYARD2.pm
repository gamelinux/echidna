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

    return 0 if ( @( $event ) != 40 );
    # validate session object

    # verify number of elements

    # verify duplicate in db
    my $dup = $db->search({
        event => {
            event_id => $event->{event}{id},
        }
    });

    return 0 if ( @{ $dup } );

    return 1;
}

sub save {
    my ($self, $event) = @_;


    # validation
    $self->validate( $event );

    my $db = NSMF::Server->database();

    return $db->insert({
        event => {
            id => $event->[1]+0,
            timestamp => $event->[3]+0,
            classification => 0,
        },
        node => {
            id => $event->[0]+0,
        },
        net => {
            version => $event->[10]+0,
            protocol => $event->[15]+0,
            source => {
                ip => $event->[11],
                port => $event->[12]+0
            },
            destination => {
                ip => $event->[13],
                port => $event->[14]+0
            }
        },
        signature => {
            type => 1
            id => $event->[5]+0,
            revision => $event->[6]+0,
            message => $event->[7],
            priority => $event->[8]+0,
            category => $event->[9]
        },
        vendor_meta => {
            u2_event_id => $event->[2]+0,
            u2_filename => ''
        }
    });
}

1;
