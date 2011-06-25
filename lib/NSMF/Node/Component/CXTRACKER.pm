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
package NSMF::Node::Component::CXTRACKER;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Node::Component);

#
# PERL INCLUDES
#
use Data::Dumper;
use POE;

#
# NSMF INCLUDES
#
use NSMF::Node;
use NSMF::Common::Logger;
use NSMF::Util;

#
# GLOBALS
#
our $VERSION = '0.1';
our $cxtdir;
my $logger = NSMF::Common::Logger->new();

sub  hello {
    $logger->debug('   Hello from CXTRACKER Node!!');
}
sub run {
    my ($self, $kernel, $heap) = @_;
     
    $self->register($kernel, $heap);
    $logger->debug("Running cxtracker processing..");

    $self->hello();

    $cxtdir = $self->{__settings}->{cxtdir};
    $heap->{watcher} = $self->file_watcher({
        directory => $cxtdir,
        callback  => '_process',
        interval  => 3,
        pattern   => 'stats\..+\.(\d){10}'
    });
}

sub _process {
    my ($self, $file) = @_;
    my $cxtdir = $self->{__settings}->{cxtdir};
    
    return unless defined $file and -r -w -f $file;

    $logger->error('CXTDIR undefined!') unless $cxtdir;

    my ($sessions, $start_time, $end_time, $process_time, $result);

    $logger->info("[*] Found file: $file");

    $start_time   = time();
    $sessions     = _get_sessions($file);
    $end_time     = time();
    $process_time = $end_time - $start_time;

    $logger->debug("[*] File $file processed in $process_time seconds");

    $start_time   = $end_time;
    $self->post(cxt => $sessions);
    $end_time     = time();
    $process_time = $end_time - $start_time;

    $logger->debug("[*] Session record sent in $process_time seconds");

    $logger->debug("[W] Deleting file: $file");

    unlink($file) or $logger->error("Failed to delete $file");
}

=head2 _get_sessions

 This sub extracts the session data from a session data file.
 Takes $file as input parameter.

=cut

sub _get_sessions {
    my $sfile = shift;
    my $sessions_data = qq();

    if (open (FILE, $sfile)) {
        if ($NSMF::DEBUG) {
            my $filelen=`wc -l $sfile |awk '{print \$1'}`;
            my $filesize=`ls -lh $sfile |awk '{print \$5}'`;

            chomp $filelen;
            chomp $filesize;

            $logger->debug("[*] File:$sfile, Lines:$filelen, Size:$filesize");
        }

        # Verify the data in the session files
        LINE:
        while (my $line = readline FILE) {
            chomp $line;
            $line =~ /^\d{19}/;
            unless($line) {
                warn "[*] Error: Not valid session start format in: '$sfile'";
                next LINE;
            }
            my @elements = split/\|/,$line;
            unless(@elements == 15) {
                warn "[*] Error: Not valid Nr. of session args format in: '$sfile'";
                next LINE;
            }
            # Things should be OK now to send to the SERVER
            if ( $sessions_data eq "" ) {
                $sessions_data = "$line";
            } else {
                $sessions_data .= "\n$line";
            }
      }

      close FILE;
      $logger->debug("Sessions data:\n$sessions_data");
      return $sessions_data;
    }
}

1;
