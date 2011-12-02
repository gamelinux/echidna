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
use AnyEvent;
use Carp;
use Data::Dumper;

#
# NSMF INCLUDES
#
use NSMF::Agent;
use NSMF::Agent::Action;

use NSMF::Common::Util;

#
# CONSTATS
#
our $VERSION = {
  major    => 0,
  minor    => 1,
  revision => 0,
  build    => 2,
};


#
# IMPLEMENTATION
#

sub type {
    return "CXTRACKER";
}

sub sync {
    my $self = shift;

    $self->SUPER::sync();

    my $settings = $self->{__config}->settings();

    $self->logger->error('CXTDIR undefined!') unless $settings->{cxtdir};

    $self->{watcher} = NSMF::Agent::Action->file_watcher({
        directory => $settings->{cxtdir},
        callback  => sub { $self->_process(@_); },
        interval  => 3,
        pattern   => 'stats\..+\.(\d){10}'
    });
}

sub run {
    my $self = shift;

    $self->logger->debug('Running cxtracker node...');
}


sub _process {
    my ($self, $file) = @_;

    # there is no point sending if we're not connected to the server
    # we need a valid node_id to mark identify all our communications
    return if( ! $self->connected() );
    return if( $self->{__node_id} < 0 );

    return unless defined $file;

    if ( ! ( -r -w -f $file ) )
    {
        $self->logger->info('Insufficient permissions to operate on file: ' . $file);
        return;
    };

    $self->logger->info("Found file: $file");

    my ($sessions, $start_time, $end_time, $process_time, $result);

    $start_time   = time();
    $sessions     = $self->_get_sessions($file);

    if ( @{ $sessions } ) {
        $self->{__proto}->post('cxtracker.save', $sessions);

        $end_time     = time();
        $process_time = $end_time - $start_time;

        $self->logger->debug("Session record(s) processed and sent in $process_time seconds");
    }

    unlink($file) or $self->logger->error("Failed to delete: $file");
}

=head2 _get_sessions

 This sub extracts the session data from a session data file.
 Takes $file as input parameter.

=cut

sub _get_sessions {
    my ($self, $sfile) = @_;
    my $sessions_data = [];

    my $logger = NSMF::Common::Registry->get('log');

    $logger->debug('Session file found: ' . $sfile);

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

            unless(@elements == 19) {
                $logger->error("Not valid number of session args format in: '$sfile'");
                next;
            }

            # build the session structs
            push( @{ $sessions_data }, $line);
        }

        close FILE;

        return $sessions_data;
    }
}

1;
