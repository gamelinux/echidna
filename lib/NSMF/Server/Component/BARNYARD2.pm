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
package NSMF::Server::Component::BARNYARD2;

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
use NSMF::Model::Event;
use NSMF::Server;
use NSMF::Common::Registry;

#
# GLOBALS
#
my $logger = NSMF::Common::Registry->get('log') 
    // carp 'Got an empty config object from Registry';

#
# MEMBERS
#

sub get_registered_methods {
    my ($self) = @_;

    return [
        {
            method => 'barnyard2.save',
            acl    => 0,
            func   => sub{ $self->save(@_); }
        },
        {
            method => 'barnyard2.get_max_eid',
            acl    => 0,
            func   => sub{ $self->node_max_eid_get(@_); }
        }
    ];
}

sub node_max_eid_get
{
    my ($self, $node, $json, $cb_success, $cb_error) = @_;

    my $db = NSMF::Server->database();

    $db->call(event => 'get_max_id' => { node_id => $node->{details}{id} }, sub {
        my ($rs, $err) = @_;

        return $cb_error->($err) if $err;

        $logger->debug($rs);

        if( @$rs ) {
          $cb_success->($json, $rs->[0]{id});
        }
        else {
          $cb_success->($json, 0);
        }

    });
}

sub save {
    my ($self, $node, $json, $cb_success, $cb_error) = @_;

    my $event = $json->{params};

    my @event_fields = split(/\|/, $event);

    # validation the event data received
    my $validation = $self->validate( \@event_fields );

    my $event_id = $event_fields[2]+0;

    if ($validation == 0) {
        return $cb_success->(0);
    }
    elsif ( $validation == 2 ) {
        return $cb_success->($event_id);
    }

    my $db = NSMF::Server->database();

    $event = NSMF::Model::Event->new({
        id => $event_id,
        timestamp => $event_fields[4],
        classification => 0,
        node_id => $event_fields[1]+0,
        net_version => $event_fields[11]+0,
        net_protocol => $event_fields[16]+0,
        net_src_ip => $event_fields[12],
        net_src_port => $event_fields[13]+0,
        net_dst_ip => $event_fields[14],
        net_dst_port => $event_fields[15]+0,
        sig_type => 1,
        sig_id => $event_fields[6]+0,
        sig_revision => $event_fields[7]+0,
        sig_message => $event_fields[8],
        sig_priority => $event_fields[9]+0,
        sig_category => $event_fields[10],
    });

    $event->meta($event_fields[39]) if ( @event_fields >= 40 );

    $db->insert(event => $event, sub {
        my $ret = shift;

        if( $ret ) {
           $cb_success->($json, $event_id);
        }
        else {
           $cb_success->($json, -1);
        }
    });
}

sub validate {
    my ($self, $event) = @_;

    my $db = NSMF::Server->database();

    # verify number of elements
    my $event_fields = @{ $event };

    if ( @{ $event } < 16 )
    {
        $logger->debug('Insufficient fields in EVENT line. Got ' . $event_fields . ' and expected 25.', $event);
        return 0;
    }

    return 1;
}

1;
