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
package NSMF::Agent::Action;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use AnyEvent;

#
# NSMF INCLUDES
#

#
# GLOBALS
#

sub file_watcher {
    my ($self, $settings) = @_;

    require NSMF::Common::Registry;
    my $logger = NSMF::Common::Registry->get('log');

    $logger->fatal('Expected hash ref of parameters. Got: ', $settings) if ( ! ref($settings) );

    my $dir      = $settings->{directory} // $logger->fatal('Directory Expected');
    my $time     = $settings->{interval}  // 3;
    my $cb       = $settings->{callback}  // $logger->fatal('Callback Expected');
    my $regex    = $settings->{pattern}   // $logger->fatal('Regex Expected');
    my $alias    = $settings->{alias}     // 'file_watcher';

    my $w = AnyEvent->timer(
        interval => $settings->{interval},
        cb       => sub {
            my $file_back;

            $logger->debug('Checking dir: ' . $dir);

            if( opendir my $dh, $dir ) {
                while ( my $file = readdir($dh)) {
                    if ( -f "$dir/$file" and $file =~ /$regex/) {
                        $file_back = $dir . $file;
                        last;
                    }
                }

                closedir($dh);

                $cb->($file_back);
            }
            else {
                $logger->error("Could not open $dir");
            }
        },
    );

    return $w;
}

1;
