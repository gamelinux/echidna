#
# This file is part of the NSM framework
#

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
package NSMF::Server::ModMngr;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Data::Dumper;

#
# NSMF INCLUDES
#
use NSMF::Server;


sub load {
    my ($self, $module_name) = @_;

    my $module_path;
    my $nsmf    = NSMF::Server->new();
    my $config  = $nsmf->config;
    my $modules = $config->modules();

    if( lc($module_name) ~~ @$modules ) {
        $module_path = 'NSMF::Server::Component::' . uc($module_name);
        eval "use $module_path";

        if( $@ ) {
            die { status => 'error', message => "Failed to load module $module_name: $@" };
        }
        else {
            return $module_path->new;
        }
    }

    die { status => 'error', message => 'Module Not Enabled' }; 
}

1;
