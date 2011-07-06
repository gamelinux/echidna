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

    # validate session object

    # verify number of elements
    unless(@elements == 15) {
        die { status => 'error', message => 'Invalid number of elements' };
    }

    # verify duplicate in db
    my $class = ref $self;
    if ($class->search({ session_id => $elements[0] })->next) {
        die { status => 'error', message => 'Duplicated Session' };
    }

    return 1;
}

sub save {
    my ($self, $session) = @_;

    # validation
    $self->validate( $session );

    my $db = NSMF::Server->database();

    return $db->insert($session);
}

1;
