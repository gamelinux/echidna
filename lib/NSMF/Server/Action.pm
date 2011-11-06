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
package NSMF::Server::Action;

use warnings;
use strict;
use v5.10;

use Carp;

#
# PERL INCLUDES
#
use POE;
use POE::Wheel::Run;
use Data::Dumper;
use Carp;

#
# NSMF INCLUDES
#
use NSMF::Common::Registry;

#
# GLOBALS
#
my $logger = NSMF::Common::Registry->get('log') 
    // carp 'Got an empty config object from Registry';

sub file_catcher {
    my ($self, $settings) = @_;

    $logger->fatal('Expected hash ref of parameters. Got: ', $settings) if ( ! ref($settings) );

    my $trx_id   = $settings->{transfer_id}   // $logger->fatal('Transfer Id Expected');
    my $checksum = $settings->{checksum}      // $logger->fatal('Checksum Expected');

    return POE::Session->create(
        inline_states => {
            _start => sub {
                $_[KERNEL]->yield('catch');
                $_[KERNEL]->alias_set('listener_'. $trx_id);
                $_[HEAP]{job_id} = $trx_id;
            },
            got_signal => sub {
                my ($pid, $status) = @_[ARG1, ARG2];
                given($status) {
                    when(/^0$/) {
                        $logger->debug("PCAP Transferred Successfully");
                    }
                    when(/2304/) {
                        $logger->debug("PCAP Listener Transfer Failed!");
                    }
                    default {
                        $logger->debug("Listener pid $pid exited with status $status.");
                    }
                }

                my $child = delete $_[HEAP]{transfer_by_pid}{$pid};

                # May have been reaped by on_child_close().
                return unless defined $child;

                delete $_[HEAP]{transfer_by_wid}{$child->ID};

                # Remove transfer session from queue
                $_[KERNEL]->post(transfer_mngr => queue_remove => $_[HEAP]{job_id});
            },
            catch => sub {
                my ($kernel, $heap) = @_[KERNEL, HEAP];

                $logger->debug("Spawning Listener..");

                say $NSMF::Server::BASE_PATH .'/script/listener.pl';
                # get unique job id
                my $child  = POE::Wheel::Run->new(
                    Program => [
                        $NSMF::Server::BASE_PATH . '/scripts/listener.pl'
                        #$checksum,
                    ],
                    StdoutEvent => sub {
                        my ($stderr_line, $wheel_id) = @_[ARG0, ARG1];
                        my $child = $_[HEAP]{transfer_by_wid}{$wheel_id};
                        $logger->debug("pid ", $child->PID, " LISTENER: $stderr_line");
                    },
                    StderrEvent => sub {
                        my ($stderr_line, $wheel_id) = @_[ARG0, ARG1];
                        my $child = $_[HEAP]{transfer_by_wid}{$wheel_id};
                        $logger->debug("pid ", $child->PID, " STDERR: $stderr_line");
                    },
                    CloseEvent => sub {
                        my $wheel_id = $_[ARG0];
                        my $child = delete $_[HEAP]{transfer_by_wid}{$wheel_id};

                        unless (defined $child) {
                        $logger->debug("wid $wheel_id closed all pipes.");
                        return;
                        }

                        $logger->debug("pid ", $child->PID, " closed all pipes.");
                        delete $_[HEAP]{transfer_by_pid}{$child->PID};
                    },
                );

                $kernel->sig_child($child->PID, "got_signal");
                $_[HEAP]{transfer_by_wid}{$child->ID} = $child;
                $_[HEAP]{transfer_by_pid}{$child->PID} = $child;

                $logger->debug("Listener pid ". $child->PID ." started as wheel". $child->ID. ".");
            },
        },
    );
}

1;
