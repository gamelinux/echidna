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
use POE;

#
# NSMF INCLUDES
#
use NSMF::Common::Logger;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

sub file_watcher {
    my ($self, $settings) = @_;

    $logger->fatal('Expected hash ref of parameters') if ( ! ref($settings) );

    my $dir      = $settings->{directory}  // $logger->fatal('Directory Expected');
    my $time     = $settings->{interval}   // 3;
    my $callback = $settings->{callback}   // $logger->fatal('Callback Expected');
    my $regex    = $settings->{pattern}    // $logger->fatal('Regex Expected');

    return POE::Session->create(
        inline_states => {
            _start => sub { 
                $_[KERNEL]->yield('watch'); 
                $_[KERNEL]->alias_set('file_seeker');
            },
            watch => sub {
                my ($kernel) = $_[KERNEL];
                my $file_back;
                opendir my $dh, $dir or die "Could not open $dir";
                while ( my $file = readdir($dh)) {
                    if ( -f "$dir/$file" and $file =~ /$regex/) {
                        $file_back = $dir . $file;
                        last;
                    }
                } 
                closedir $dh;
                $self->$callback($file_back);
                $kernel->delay( watch => $time);
            },
        }
    );
}

1;
