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
package NSMF::Server::DBMngr;

use warnings;
use strict;
use v5.10;

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

#
# database_settings => {
#     type => ['mysql', 'pgsql', 'etc']
#     host =>
#     port =>
#     name =>
#     user =>
#     pass =>
# }
#


sub create {
    my ($self, $database) = @_;

    $logger = NSMF::Common::Registry->get('log');

    my $type = $database->{type} // 'MYSQL';

    my $db_path = 'NSMF::Server::DB::' . uc($type);

    my @databases = NSMF::Server->databases();
    if ( $db_path ~~ @databases ) {
        eval "use $db_path";
        if ( $@ ) {
            die { status => 'error', message => 'Failed to load DB source ' . $@ };
        };

        $logger->debug('Creating DB manager: ' . $type);

        # instatiate the database object and create the connection
        my $db = $db_path->instance();

        eval {
            $db->create($database);
        };

        if ( $@ )
        {
            $logger->fatal($@);
        }

        return $db;
    }
    else {
        die { status => 'error', message => 'DB source "' . $type . '" not supported.' };
    }
}

1;
