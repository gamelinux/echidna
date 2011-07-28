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
package NSMF::Agent::Component::BARNYARD2;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Agent::Component);

#
# PERL INCLUDES
#
use Data::Dumper;
use POE;
use POE::Component::Server::TCP;

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

my $VERSION = "PLATYPUS-0.1.0";
my $SVR_CONNECTED = 0;
my $PORT_SCAN_FILEWAIT = 0;
my $BY2_CONNECTED = 0;
my $MAX_EID = -1;

sub type {
    return "BARNYARD2";
}

sub hello {
    my ($self) = shift;
    $logger->debug('Hello from BARNYARD2 node!!');
}

sub run {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $self = shift;

    $logger->debug("Running barnyard2 processing..");

    $self->hello();

    my $settings = $self->{__config}->settings();

    # get barnyard2 listener options with sane defaults
    my $host = $settings->{barnyard2}{host} // "localhost";
    my $port = $settings->{barnyard2}{port} // 7060;

    my $listener = new POE::Component::Server::TCP(
        Alias         => 'barnyard2',
        Address       => $host,
        Port          => $port,
        ClientConnected => sub {
          my ($session, $heap) = @_[SESSION, HEAP];

          $logger->debug('Barnyard2 instance connected: ' . $heap->{remote_ip});

          $heap->{node_id} = -1;
          $heap->{eid_max} = -1;

          $kernel->yield('barnyard2_sync');
        },
        ClientDisconnected => sub {
        },
        ClientInput => sub {
            my ($kernel, $response) = @_[KERNEL, ARG0];

            $kernel->yield('barnyard2_dispatcher', $response);
        },
        ClientFilter  => "POE::Filter::Line",
        ObjectStates => [
            $self => [ 'run', 'ident_node_get', 'barnyard2_dispatcher' ]
        ],
    );
}

sub _get_sessions {
    my ($sfile, $node_id) = @_;
    my $sessions_data = [];

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
                    id => $node_id,
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

#
# STATS (SNORT) FUNCTIONS/HANDLERS
#

sub stats_error
{
  my ($kernel, $heap, $op, $errno, $errstr, $id) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2, ARG3];

  $logger->debug("ERROR: $op ($id) generated $errstr ($errno)");

  server_send({
    "message" => {
      "type" => "system",
      "data" => $errstr,
    }
  });

  # re-init after time delay (60s)
  $kernel->delay("stats_init", 60);
}

sub stats_init
{
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  my $stats_file = "";

  if ( ! -e $stats_file )
  {
    server_send({
      "message" => {
        "type" => "system",
        "data" => "ERROR: " . $stats_file . " does not exist. Unable to monitor stats."
      }
    });

    # re-init after time delay (60s)
    $kernel->delay("stats_init", 60);
    return;
  }
  elsif ( ! -r $stats_file )
  {
    server_send({
      "message" => {
        "type" => "system",
        "data" => "ERROR: " . $stats_file . " is not readable. Unable to monitor stats."
      }
    });

    # re-init after time delay (60s)
    $kernel->delay("stats_init", 60);
    return;
  }

  $heap->{wheel_stats} = POE::Wheel::FollowTail->new(
    Filename        => $stats_file,
    InputEvent      => "stats_input",
    ResetEvent      => "stats_reset",
    ErrorEvent      => "stats_error",
  );
}

sub stats_input
{
  my $kernel = $_[KERNEL];
  my $heap = $_[HEAP];
  my $data = $_[ARG0];

  stats_process($kernel, $heap, $data);
}

sub stats_process
{
  my ($kernel, $heap, $data) = @_;

  my @data_tabs = split(/,/, $data);

  if ( $data_tabs[0] =~ /\D/ )
  {
      server_send({
          "message" => {
              "type" => "system",
              "data" => "ERROR: Invalid snort stats line (" . $data. ")."
        }
      });
      return;
  }

  my $stats = join("|", @data_tabs[1..6, 9..11]);

  # append timestamp

  #lappend snortStatsList [clock format [lindex $dataList 0] -gmt true -f "%Y-%m-%d %T"]

  stats_send($kernel, $heap, $stats);
}

sub stats_send
{
    my ($kernel, $heap, $stats) = @_;

    # check if we have a valid sensor ID for sending
    if ( $heap->{node_id} < 0 )
    {
        # rinit after time delay (30s)
        $kernel->delay("send_stats", 30);
        return;
    }

    # check we have valid data for sending
    if ( length($stats) == 0 )
    {
        return;
    };

    # push the sensor ID to the front of the snort stats list before sending
    $stats = $heap->{node_id} . "|" . $stats;

    # send the stats to the server
    server_send({
        "snort_stats" => $stats
    });
}

#
# BARNYARD2 FUNCTIONS/HANDLERS
#

sub barnyard2_error
{
  my $kernel = $_[KERNEL];
  my $heap = $_[HEAP];
  my ($op, $errno, $errstr, $id) = ($_[ARG0], $_[ARG1], $_[ARG2], $_[ARG3]);

  # delete our wheel for socket
  delete $heap->{socket_by2};
  delete $heap->{wheel_by2};

  # attempt to recover from connection loss (0, 111)
  if ($errno == 0 || $errno == 111)
  {
    $logger->debug("barnyard2 seems to have disappeared.");

    # re-init after time delay (30s)
    $kernel->delay("barnyard2_init", 30);
  }
  else
  {
    $logger->debug("ERROR: $op ($id) generated $errstr ($errno)");
    server_send({
      "message" => {
        "type" => "system",
        "data" => $errstr,
      }
    });
  }
}

sub barnyard2_dispatcher
{
    my ($kernel, $heap, $data) = @_[KERNEL, HEAP, ARG0];

    # clean up any leading \0 which are artefacts of banyard2's C string \0 terminators
    if ( ord(substr($data, 0, 1)) == 0 ) {
        $data = substr($data, 1);
    }

    my @data_tabs = split(/\|/, $data);

    $logger->debug("Received from barnyard2: " . $data . " (" . @data_tabs . ")");

    given($data_tabs[0]) {
        # agent sensor/event id request
        when("BY2_SEID_REQ") {
            # no need to push to server if we've received a valid max_eid
            if ( $heap->{node_id} != -1 &&
                 $heap->{eid_max} != -1 )
            {
                $heap->{client}->put("BY2_SEID_RSP|" . $heap->{node_id} . "|" . $heap->{eid_max});
            }
            else
            {
                if ( $heap->{node_id} < 0 ) {
                  $heap->{node_id} = $kernel->call('node', 'ident_node_get');
                }
                else {
                    $kernel->post('node', 'post', {
                        action => 'node_max_eid_get',
                        parameters => {
                            node_id => $heap->{node_id}
                        }
                    }, sub {
                        my ($self, $kernel, $heap, $json) = @_;

                        $logger->debug($heap);

                        if( defined($json->{result}) )
                        {
                            $logger->debug('Updating.');
                            $heap->{eid_max} = $json->{result} + 0;
                        }
                    });
                };
            }
        }
        # alert event
        when("BY2_EVT") {
            # forward to server
            my @tmp_data = @data_tabs[1..$#data_tabs];
            server_send({
              "action" => "event_alert",
              "parameters" => \@tmp_data
            });
        }
        default {
            $logger->error("Unknown barnyard2 command: \"" . $data_tabs[0] . "\" (" . length($data_tabs[0]) . ")");
        }
    }
}

sub barnyard2_send
{
  my ($command, @data) = @_;

  my $message = $command;

  # attach the data as appropriate
  if (@data)
  {
    foreach my $d (@data)
    {
      $message .= "|" . $d;
    }
  }

  if ( !$BY2_CONNECTED )
  {
    $logger->debug("Not connected to barnyard2. Unable to send: " . $message);
  }
  else
  {
    $logger->debug("Sending to barnyard2: " . $message);
    #$heap->{wheel_by2}->put($message);
  }
}

#
# SERVER (PLATYPUS) FUNCTIONS/HANDLERS
#

sub server_error
{
  my ($kernel, $heap, $op, $errno, $errstr, $id) = @_[KERNEL, KERNEL, ARG0, ARG1, ARG2, ARG3];

  $logger->debug("ERROR: $op ($id) generated $errstr ($errno)");

  # attempt to recover from connection loss (111, 0)
  if ($errno == 0 || $errno == 111)
  {
    $logger->debug("The server seems to have disappeared.");

    # re-init after time delay (15s)
    $kernel->delay("server_init", 15);
    $SVR_CONNECTED = 0;
  }
  else
  {
    $logger->debug("ERROR: $op ($id) generated $errstr ($errno)");
  }
}

sub server_ping
{
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  my $PING_DELAY = 5;

  if ( $SVR_CONNECTED )
  {
    server_send({"ping"});
  }

  $kernel->delay("server_ping", $PING_DELAY);

  return 0;
}

#
#
sub server_connected
{
  my $heap = $_[HEAP];
  my $server_socket = $_[ARG0];

  # set flag
  $SVR_CONNECTED = 1;
  log_normal("Connected to Platypus server.");

  # create the wheel to watch this socket
  $heap->{wheel_svr} = POE::Wheel::ReadWrite->new (
    Handle      => $server_socket,
    InputEvent    => "server_input",
    ErrorEvent    => "server_error",
  );

  # send a version match check
  server_send({"action" => "agent_version_get"});

  return 0;
}

sub server_input
{
  my ($kernel, $session, $heap, $data) = @_[KERNEL, SESSION, HEAP, ARG0];

  $logger->debug("Received from server: $data");

  my $json = decode_json($data);

  given( $json->{"action"} )
  {
    # agent information set
    when("agent_information_set") {
      agent_info($json->{"parameters"});
    }
    # agent event received confirmation
    when("agent_event_confirm") {
      barnyard2_send("BY2_EVT_CFM", $json->{"parameters"});

      # confirmation indicates the event successfully stored
      $MAX_EID++;
    }
    # agent sensor/event id response
    when("agent_seid_response") {
      barnyard2_send("BY2_SEID_RSP", $json->{"parameters"});
    }
    default {
      $logger->error("Unknown command received: " . $json->{"action"});
    }
  }

  return 0;
}

1;
