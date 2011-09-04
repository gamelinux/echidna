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
use NSMF::Server;
use NSMF::Common::Logger;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

sub hello {
    $logger->debug("Hello World from CXTRACKER Module!!");
    my $self = shift;
    $_->hello for $self->plugins;
}

sub validate {
    my ($self, $session) = @_;

    my $db = NSMF::Server->database();

    return 1;
    # validate session object

    # verify number of elements

    # verify duplicate in db
    my $dup = $db->search({
        session => {
            session_id => $session->{session}{id},
        }
    });

    if ( @{ $dup } ) {
        die { status => 'error', message => 'Duplicated Session' };
    }

    return 1;
}

sub process {
    my ($self, $session) = @_;

    # validation
    $self->validate( $session );

#


    my $db = NSMF::Server->database();

    return $db->insert( { session => $session } );
}

1;
