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
package NSMF::Agent::Component::CXTRACKER;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Agent::Component);

#
# PERL INCLUDES
#
use Data::Dumper;
use POE;

#
# NSMF INCLUDES
#
use NSMF::Agent;
use NSMF::Agent::Action;
use NSMF::Common::Logger;
use NSMF::Common::Util;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

sub hello {
    my ($self) = shift;
    $logger->debug('   Hello from CXTRACKER Node!!');
}

sub run {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $self = shift;

    $self->register($kernel, $heap);
    $logger->debug("Running cxtracker processing..");

    $self->hello();

    my $settings = $self->{__config}->settings();

    $logger->error('CXTDIR undefined!') unless $settings->{cxtdir};

    $heap->{watcher} = NSMF::Agent::Action->file_watcher({
        directory => $settings->{cxtdir},
        callback  => [ $self, '_process' ],
        interval  => 3,
        pattern   => 'stats\..+\.(\d){10}'
    });
}

sub _process {
    my ($kernel, $heap, $file) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    return unless defined $file and -r -w -f $file;

    my ($sessions, $start_time, $end_time, $process_time, $result);

    $logger->info("Found file: $file");

    $start_time   = time();
    $sessions     = _get_sessions($file);
    $end_time     = time();
    $process_time = $end_time - $start_time;

    $logger->debug("File $file processed in $process_time seconds");

    $start_time   = $end_time;
    for my $session ( @{ $sessions } )
    {
        $kernel->post('node', 'post', $session);
    }
    $end_time     = time();
    $process_time = $end_time - $start_time;

    $logger->debug("Session record sent in $process_time seconds");

    unlink($file) or $logger->error("Failed to delete: $file");
}

=head2 _get_sessions

 This sub extracts the session data from a session data file.
 Takes $file as input parameter.

=cut

sub _get_sessions {
    my $sfile = shift;
    my $sessions_data = [];

    if ( open(FILE, $sfile) ) {
        my $cnt = 0;
        # verify the data in the session files
        while (my $line = readline FILE) {
            chomp $line;
            $line =~ /^\d{19}/;
            unless($line) {
                $logger->error("Not valid session start format in: '$sfile'");
                next;
            }

            my @elements = split(/\|/, $line);

            unless(@elements == 15) {
                $logger->error("Not valid number of session args format in: '$sfile'");
                next;
            }

            # build the session structs
            push( @{ $sessions_data }, {
                session => {
                    id => $elements[0],
                    timestamp => 0,
                    times => {
                        start => $elements[1],
                        end   => $elements[2],
                        duration => $elements[3],
                    },
                },
                node => {
                    id => 0,
                },
                net => {
                    version => 4,
                    protocol => $elements[4],
                    source => {
                        ip   => $elements[5],
                        port => $elements[6],
                        total_packets => $elements[9],
                        total_bytes => $elements[10],
                        flags => $elements[13],
                    },
                    destination => {
                        ip   => $elements[7],
                        port => $elements[8],
                        total_packets => $elements[11],
                        total_bytes => $elements[12],
                        flags => $elements[14],
                    },
                },
                data => {
                    filename => 'filename.ext',
                    offset => 0,
                    length => 0,
                },
                vendor_meta => {
                    cxt_id => $elements[0],
                },
            });
        }

        close FILE;

        return $sessions_data;
    }
}

1;
