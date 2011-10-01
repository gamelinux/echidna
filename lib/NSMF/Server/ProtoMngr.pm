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
package NSMF::Server::ProtoMngr;

use warnings;
use strict;
use v5.10;

#
# NSMF INCLUDES
#
use NSMF::Server;

sub create {
    my ($self, $class, $type) = @_;

    $class //= 'NODE';
    $type //= 'JSON';

    my $proto_path;
    my @protocols;

    given( $class ) {
        when(/^client$/i) {
            @protocols = NSMF::Server->client_protocols();
            $proto_path = 'NSMF::Server::Proto::Client::' . uc($type);
        }
        when(/^node$/i) {
            @protocols = NSMF::Server->node_protocols();
            $proto_path = 'NSMF::Server::Proto::Node::' . uc($type);
        }
        default {
            die { status => 'error', message => 'Unknown class type: ' . $class };
        }
    }

    if ( ! ( $proto_path ~~ @protocols ) ) {
        die { status => 'error', message => 'Protocol is not supported' };
    }

    eval "use $proto_path";
    if ( $@ ) {
        die { status => 'error', message => 'Failed to load ' . $class . ' protocol! ' . $@ };
    };

    return $proto_path->instance;
}

1;
