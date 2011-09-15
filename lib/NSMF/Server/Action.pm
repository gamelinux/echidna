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

#
# PERL INCLUDES
#
use POE;
use POE::Wheel::Run;

#
# NSMF INCLUDES
#
use NSMF::Common::Logger;

#
# GLOBALS
#
my $logger = NSMF::Common::Logger->new();

sub file_catcher {
    my ($self, $settings) = @_;

    $logger->fatal('Expected hash ref of parameters. Got: ', $settings) if ( ! ref($settings) );

    my $trx_id   = $settings->{transfer_id}   // $logger->fatal('Transfer Id Expected');
    #my $dir      = $settings->{directory}     // $logger->fatal('Directory Expected');
    #my $time     = $settings->{duration}      // 60;
    #my $cb_obj   = $settings->{callback}->[0] // $logger->fatal('Callback Expected');
    #my $cb_func  = $settings->{callback}->[1] // $logger->fatal('Callback Expected');
    my $checksum = $settings->{checksum}      // $logger->fatal('Checksum Expected');


    POE::Session->create(
        inline_states => {
            _start => sub {
                $_[KERNEL]->yield('catch');
                $_[KERNEL]->alias_set('listener_'. $trx_id);
            },
            catch => sub {
                my ($kernel, $heap) = @_[KERNEL, HEAP];
                my $file_back;

                say "Spawning Listener..";

                # get unique job id
                my $child  = POE::Wheel::Run->new(
                    Program => [
                        "/home/larsx/transfer/server.pl",
                        #$checksum,
                    ],
                    StdoutEvent => "got_stdout",
                    StderrEvent => "got_stderr",
                    CloseEvent => "got_close",
                );

                $kernel->sig_child($child->PID, "got_signal");
                $_[HEAP]{transfer_by_wid}{$child->ID} = $child;
                $_[HEAP]{transfer_by_pid}{$child->PID} = $child;

                say "Listener pid ". $child->PID ." started as wheel". $child->ID. ".";
            },
        },
    );
}
    sub got_stdout {
        my ($stderr_line, $wheel_id) = @_[ARG0, ARG1];
        my $child = $_[HEAP]{transfer_by_wid}{$wheel_id};
        say "pid ", $child->PID, " LISTENER: $stderr_line";
    }

    sub got_close {
        my $wheel_id = $_[ARG0];
        my $child = delete $_[HEAP]{transfer_by_wid}{$wheel_id};

        unless (defined $child) {
            say "wid $wheel_id closed all pipes.";
            return;
        }

        say "pid ", $child->PID, " closed all pipes.";
        delete $_[HEAP]{transfer_by_pid}{$child->PID};
    }

    sub got_stderr {
        my ($stderr_line, $wheel_id) = @_[ARG0, ARG1];
        my $child = $_[HEAP]{transfer_by_wid}{$wheel_id};
        say "pid ", $child->PID, " STDERR: $stderr_line";
    }

    sub got_signal {
        say "pid $_[ARG1] exited with status $_[ARG2].";
        my $child = delete $_[HEAP]{transfer_by_pid}{$_[ARG1]};

        # May have been reaped by on_child_close().
        return unless defined $child;

        delete $_[HEAP]{transfer_by_wid}{$child->ID};
    }

1;
