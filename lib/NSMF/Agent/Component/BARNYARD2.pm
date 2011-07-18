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

#    $self->register($kernel, $heap);
    $logger->debug("Running barnyard2 processing..");

    $self->hello();

    my $settings = $self->{__config}->settings();

    #$logger->error('CXTDIR undefined!') unless $settings->{cxtdir};
}

=head2 _get_sessions

 This sub extracts the session data from a session data file.
 Takes $file as input parameter.

=cut

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
# GLOBAL VARIABLES
#
my $APPCONFIG;
my %APPVARS;

our %DBG;
$DBG{"COMMON"}    = 0x00000001;
$DBG{"BROWSER"}   = 0x00000002;
$DBG{"AGENT"}     = 0x00000004;
$DBG{"DATABASE"}  = 0x00000008;
$DBG{"WEBSOCKET"} = 0x00000010;
$DBG{"UTILITIES"} = 0x00000020;
  $DBG{"IP"}      = 0x00000040;
  $DBG{"ENCODE"}  = 0x00000080;

$DBG{"ALL"}       = 0xffffffff;



#
# LOCAL VARIABLES
#
my $VERSION = "PLATYPUS-0.1.0";
my $SVR_CONNECTED = 0;
my $PORT_SCAN_FILEWAIT = 0;
my $BY2_CONNECTED = 0;
my $SENSOR_ID = -1;
my $MAX_EID = -1;

# read the configuration before we start the kernel
config_read();

# daemonize as appropriate
if ( $APPCONFIG->get("DAEMON") == 1 )
{
  daemonize();
}

# setup the session
POE::Session->create(
  inline_states => {
    _start                  => \&parent_start,
    _stop                   => \&parent_stop,

    barnyard2_error         => \&barnyard2_error,
    barnyard2_init          => \&barnyard2_init,
    barnyard2_connected     => \&barnyard2_connected,
    barnyard2_input         => \&barnyard2_input,

    control_error           => \&control_error,
    control_init            => \&control_init,
    control_connected       => \&control_connected,
    control_input           => \&control_input,

    server_error            => \&server_error,
    server_init             => \&server_init,
    server_connected        => \&server_connected,
    server_input            => \&server_input,
    server_ping             => \&server_ping,

    stats_error             => \&stats_error,
    stats_init              => \&stats_init,
    stats_input             => \&stats_input,
  }
);

# catch interrupts
$SIG{'INT'} = sub {
  print "\n";
  parent_stop();
};

# run the main loop
$poe_kernel->run();

log_normal("Collection agent (snort) closed.");

exit;

#
# PARENT FUNCTIONS/HANDLERS
#

#
# parent_start
#
# Description:
#   Set up the sockets for barnyard2 and the platypus server. Open the snort
# stats file for reading.
#
sub parent_start
{
  my $kernel = $_[KERNEL];
  my $session = $_[SESSION];
  my $heap = $_[HEAP];

  # save kernel and session for a clean exit
  $APPVARS{"KERNEL"} = $kernel;
  $APPVARS{"SESSION"} = $session;
  $APPVARS{"HEAP"} = $heap;

  # open port for listening to barnard2
  $kernel->yield("barnyard2_init");

  # open connection to control agent
  $kernel->yield("control_init");

  # open connection to Platypus server
  $kernel->yield("server_init");

  # check if we are performing stats file checking
  if ( defined($APPCONFIG->get("SNORT_STATS_FILE")) )
  {
    # delay stats watching until the connections have settled (5s)
    $kernel->delay("stats_init", 5);
  }
}

#
#
sub parent_stop
{
  my $kernel = $APPVARS{"KERNEL"};
  my $heap = $APPVARS{"HEAP"};

  log_normal("Shutting down...");

  # clear global references and application variables
  %APPVARS = ();
  undef %APPVARS;

  # clear our alias
  $kernel->alias_remove($heap->{alias});

  # clear all alarms that may be set
  $kernel->alarm_remove_all();

  # delete all wheels and sockets
  delete $heap->{wheel_stats};
  delete $heap->{socket_svr};
  delete $heap->{wheel_svr};
  delete $heap->{socket_by2};
  delete $heap->{wheel_by2};

  # clear all events, sessions and any remaining events
  $kernel->stop();
}



#
# CONFIG FUNCTIONS/HANDLERS
#

#
#
sub config_read
{
  log_normal("Reading configuration.");

  $APPCONFIG = AppConfig->new({
    CASE   => 1,
    GLOBAL => { ARGCOUNT => ARGCOUNT_ONE, EXPAND => EXPAND_ALL }
  });

  # define command line only parameters with appropriate defaults
  $APPCONFIG->define("CONFIG_FILE|c|config=s", { DEFAULT => "SnortAgent.conf" });
  $APPCONFIG->define("VERSION|V|version!", { DEFAULT => "0" });
  $APPCONFIG->define("HELP|?|help!", { DEFAULT => "0" });

  # define command/configuration file parameters with appropriate defaults
  $APPCONFIG->define("DAEMON|d|daemon!", { DEFAULT => "0" });
  $APPCONFIG->define("DEBUG|debug=s@", { DEFAULT => "0" });
  $APPCONFIG->define("NO_UTC|l|localtime!", { DEFAULT => 0 });

  # define configuration file only (essential)
  $APPCONFIG->define("HOSTNAME");
  $APPCONFIG->define("NET_GROUP");
  $APPCONFIG->define("CTL_HOST");
  $APPCONFIG->define("CTL_PORT");
  $APPCONFIG->define("SVR_HOST");
  $APPCONFIG->define("SVR_PORT");
  $APPCONFIG->define("BY2_PORT");


  # define configuration file only (non-essential)
  $APPCONFIG->define("PING_DELAY", { DEFAULT => 0 });
  $APPCONFIG->define("SNORT_STATS_FILE");
  $APPCONFIG->define("SNORT_STATS_REFRESH", { DEFAULT => 10 });
  $APPCONFIG->define("SNORT_PORTSCAN_FILE");
  $APPCONFIG->define("SNORT_PORTSCAN_REFRESH", { DEFAULT => 10 });

  # parse the command line
  $APPCONFIG->args();

  # parse the configuration file
  if ( -r $APPCONFIG->get("CONFIG_FILE") )
  {
    $APPCONFIG->file($APPCONFIG->get("CONFIG_FILE"));
  }
  else
  {
    log_error("Unable to open configuration file.");

    usage_display();
    return;
  }

  # essential parameters check
  for my $KEY (qw(SVR_HOST SVR_PORT NET_GROUP HOSTNAME BY2_PORT CTL_HOST CTL_PORT))
  {
    if ( !defined($APPCONFIG->get($KEY)) )
    {
      log_fatal("$KEY is an essential parameter requiring definition in the configuration file.");
    }
  }

  # process the debug options
  my $debug_list = $APPCONFIG->get("DEBUG");
  my $debug = 0;

  if ( @$debug_list )
  {
    foreach my $d (@$debug_list)
    {
      if ( $d =~ /^\d+$/ )
      {
        $debug |= $d;
      }
      elsif ( $d =~ /^[A-Za-z]+$/ )
      {
        $d = uc($d);

        if ( grep { $_ eq $d } qw(COMMON BROWSER AGENT DATABASE IP ENCODE WEBSOCKET ALL) )
        {
          $debug |= $DBG{$d}
        }
      }
    }

    log_normal("Debug Level: " . $debug);
  }
  $APPVARS{"DEBUG"} = $debug;

  return;
}

#
# STATS (SNORT) FUNCTIONS/HANDLERS
#

sub stats_error
{
  my $kernel = $_[KERNEL];
  my $heap = $_[HEAP];
  my ($op, $errno, $errstr, $id) = ($_[ARG0], $_[ARG1], $_[ARG2], $_[ARG3]);

  debug($DBG{"COMMON"}, "ERROR: $op ($id) generated $errstr ($errno)");

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
  my $kernel = $_[KERNEL];
  my $heap = $_[HEAP];

  my $stats_file = $APPCONFIG->get("SNORT_STATS_FILE");

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

  # open the stats file (tailing the last line)
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
  if ( $SENSOR_ID == -1 )
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
  $stats = $SENSOR_ID . "|" . $stats;

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
    debug($DBG{"COMMON"}, "barnyard2 seems to have disappeared.");

    # re-init after time delay (30s)
    $kernel->delay("barnyard2_init", 30);
  }
  else
  {
    debug($DBG{"COMMON"}, "ERROR: $op ($id) generated $errstr ($errno)");
    server_send({
      "message" => {
        "type" => "system",
        "data" => $errstr,
      }
    });
  }
}

sub barnyard2_init
{
  my $heap = $_[HEAP];

  my $BY2_PORT = $APPCONFIG->get("BY2_PORT");

  # start a TCP server to listen for barnyard2 connections
  $heap->{socket_by2} = POE::Wheel::SocketFactory->new (
    BindAddress     => "127.0.0.1",
    BindPort        => $BY2_PORT,
    SuccessEvent    => "barnyard2_connected",
    FailureEvent    => "barnyard2_error",
    SocketProtocol  => "tcp",
  );

  debug($DBG{"COMMON"}, "Listening for local barnyard2 connections on port $BY2_PORT.");
}

sub barnyard2_connected
{
  my $heap = $_[HEAP];
  my $barnyard2_socket = $_[ARG0];

  # set flag
  $BY2_CONNECTED = 1;
  log_normal("Connected to barnyard2.");

  # create the wheel to watch this socket
  $heap->{wheel_by2} = POE::Wheel::ReadWrite->new (
    Handle      => $barnyard2_socket,
    InputEvent    => "barnyard2_input",
    ErrorEvent    => "barnyard2_error",
  );
}

sub barnyard2_input
{
  my $heap = $_[HEAP];
  my $data = $_[ARG0];

  # clean up any leading \0 which are artefacts of banyard2's C string \0 terminators
  if ( ord(substr($data, 0, 1)) == 0 )
  {
    $data = substr($data, 1);
  }

  my @data_tabs = split(/\|/, $data);

  debug($DBG{"COMMON"}, "Received from barnyard2: " . $data . " (" . @data_tabs . ")");

  switch($data_tabs[0])
  {
    # agent sensor/event id request
    case "BY2_SEID_REQ"
    {
      # no need to push to server if we've received a valid max_eid
      if ( $SENSOR_ID != -1 && $MAX_EID != -1 )
      {
        barnyard2_send("BY2_SEID_RSP|$SENSOR_ID|$MAX_EID");
      }
      else
      {
        server_send({
          "action" => "agent_seid_get",
          "parameters" => {
            "sid" => $SENSOR_ID
          }
        });
      }
    }
    # alert event
    case "BY2_EVT"
    {
      # forward to server
      my @tmp_data = @data_tabs[1..$#data_tabs];
      server_send({
        "action" => "event_alert",
        "parameters" => \@tmp_data
      });
    }
    else
    {
      log_error("Unknown barnyard2 command: \"" . $data_tabs[0] . "\" (" . length($data_tabs[0]) . ")");
    }
  }
}

sub barnyard2_send
{
  my ($command, @data) = @_;
  my $heap = $APPVARS{"HEAP"};

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
    debug($DBG{"COMMON"}, "Not connected to barnyard2. Unable to send: " . $message);
  }
  else
  {
    debug($DBG{"COMMON"}, "Sending to barnyard2: " . $message);
    $heap->{wheel_by2}->put($message);
  }
}

#
# CONTROL (PLATYPUS) FUNCTIONS/HANDLERS
#

sub control_error
{
  my $kernel = $_[KERNEL];
  my $heap = $_[HEAP];
  my ($op, $errno, $errstr, $id) = ($_[ARG0], $_[ARG1], $_[ARG2], $_[ARG3]);

  debug($DBG{"COMMON"}, "ERROR: $op ($id) generated $errstr ($errno)");

  # attempt to recover from connection loss (111, 0)
  if ($errno == 0 || $errno == 111)
  {
    debug($DBG{"COMMON"}, "The control seems to have disappeared.");

    # delete our wheel for socket
    delete $heap->{socket_ctl};
    delete $heap->{wheel_ctl};

    # re-init after time delay (15s)
    $kernel->delay("control_init", 15);
    $CTL_CONNECTED = 0;
  }
  else
  {
    debug($DBG{"COMMON"}, "ERROR: $op ($id) generated $errstr ($errno)");
  }
}

sub control_ping
{
  my $kernel = $_[KERNEL];
  my $heap = $_[HEAP];

  my $PING_DELAY = $APPCONFIG->get("CONTROL_PING_DELAY");

  if ( $CTL_CONNECTED )
  {
    control_send({"ping"});
  }

  $kernel->delay("control_ping", $PING_DELAY);

  return 0;
}

sub control_init
{
  my $heap = $_[HEAP];

  my $CTL_HOST = $APPCONFIG->get("CTL_HOST");
  my $CTL_PORT = $APPCONFIG->get("CTL_PORT");

  # create a socket and connect to the controller
  $heap->{socket_ctl} = POE::Wheel::SocketFactory->new (
    RemoteAddress   => $CTL_HOST,
    RemotePort    => $CTL_PORT,
    SuccessEvent  => "control_connected",
    FailureEvent  => "control_error",
    SocketProtocol  => "tcp",
  );

  debug($DBG{"COMMON"}, "Connecting to Agent controller on $CTL_HOST:$CTL_PORT.");

  return 0;
}

#
#
sub control_connected
{
  my $heap = $_[HEAP];
  my $control_socket = $_[ARG0];

  # set flag
  $CTL_CONNECTED = 1;
  log_normal("Connected to Agent controller.");

  # create the wheel to watch this socket
  $heap->{wheel_ctl} = POE::Wheel::ReadWrite->new (
    Handle      => $control_socket,
    InputEvent    => "control_input",
    ErrorEvent    => "control_error",
  );

  # send a version match check
  server_send({"action" => "agent_version_get"});

  return 0;
}

sub control_input
{
  my $kernel = $_[KERNEL];
  my $session = $_[SESSION];
  my $heap = $_[HEAP];
  my $data = $_[ARG0];

  debug($DBG{"COMMON"}, "Received from controller: $data");

  my $json = decode_json($data);

  switch ( $json->{"action"} )
  {
    case "ping"
    {
      # respond with a pong
      control_send({"action" => "pong"});
    }
    case "pong"
    {
      # received a pong, no action required
    }
    # agent version response
    case "agent_version_required"
    {
      return if ( ! exists($json->{"params"}{"version"}) );

      if ( $json->{"params"}{"version"} eq $VERSION )
      {
        my $hostname = $APPCONFIG->get("HOSTNAME");
        my $net_group = $APPCONFIG->get("NET_GROUP");

        server_send({
          "action" => "agent_register",
          "parameters" => {
            "type" => "snort",
            "hostname" => $hostname,
            "net_group" => $net_group
          }
        });

        $kernel->yield("server_ping") if ( $APPCONFIG->get("PING_DELAY") != 0 )
      }
      else
      {
        # version mismatch
        log_error("Platypus Server requires version " . $json->{"parameters"}{"version"} . " but found " . $VERSION . ".");

        # exit
        $kernel->call($session, "_stop");
      }
    }
  }

  return 0;
}

sub control_send
{
  my ($r_data) = @_;
  my $heap = $APPVARS{"HEAP"};

  if ( ref($r_data) ne "HASH" )
  {
    debug($DBG{"BROWSER"}, "Ignoring due to not seeing a HASH REF! (" . ref($r_data) . ")");
    return;
  }

  # append a timestamp
  $r_data->{"timestamp"} = timestamp_now_get();

  # JSON enocde our response
  my $message = encode_json($r_data);

  if ( !$CTL_CONNECTED )
  {
    debug($DBG{"COMMON"}, "Not connected to Agent controller. Unable to send: " . $message);
  }
  else
  {
    debug($DBG{"COMMON"}, "Sending to Agent controller: " . $message);
    $heap->{wheel_ctl}->put($message);
  }

  return 0;
}

#
# SERVER (PLATYPUS) FUNCTIONS/HANDLERS
#

sub server_error
{
  my $kernel = $_[KERNEL];
  my $heap = $_[HEAP];
  my ($op, $errno, $errstr, $id) = ($_[ARG0], $_[ARG1], $_[ARG2], $_[ARG3]);

  debug($DBG{"COMMON"}, "ERROR: $op ($id) generated $errstr ($errno)");

  # attempt to recover from connection loss (111, 0)
  if ($errno == 0 || $errno == 111)
  {
    debug($DBG{"COMMON"}, "The server seems to have disappeared.");

    # delete our wheel for socket
    delete $heap->{socket_svr};
    delete $heap->{wheel_svr};

    # re-init after time delay (15s)
    $kernel->delay("server_init", 15);
    $SVR_CONNECTED = 0;
  }
  else
  {
    debug($DBG{"COMMON"}, "ERROR: $op ($id) generated $errstr ($errno)");
  }
}

sub server_ping
{
  my $kernel = $_[KERNEL];
  my $heap = $_[HEAP];

  my $PING_DELAY = $APPCONFIG->get("PING_DELAY");

  if ( $SVR_CONNECTED )
  {
    server_send({"ping"});
  }

  $kernel->delay("server_ping", $PING_DELAY);

  return 0;
}

sub server_init
{
  my $heap = $_[HEAP];

  my $SVR_HOST = $APPCONFIG->get("SVR_HOST");
  my $SVR_PORT = $APPCONFIG->get("SVR_PORT");

  # start a TCP server to listen for barnyard2 connections
  $heap->{socket_svr} = POE::Wheel::SocketFactory->new (
    RemoteAddress   => $SVR_HOST,
    RemotePort    => $SVR_PORT,
    SuccessEvent  => "server_connected",
    FailureEvent  => "server_error",
    SocketProtocol  => "tcp",
  );

  debug($DBG{"COMMON"}, "Connecting to Platypus server on $SVR_HOST:$SVR_PORT.");

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
  my $kernel = $_[KERNEL];
  my $session = $_[SESSION];
  my $heap = $_[HEAP];
  my $data = $_[ARG0];

  debug($DBG{"COMMON"}, "Received from server: $data");

  my $json = decode_json($data);

  switch ( $json->{"action"} )
  {
    case "ping"
    {
      # respond with a pong
      server_send({"action" => "pong"});
    }
    case "pong"
    {
      # received a pong, no action required
    }
    # agent version response
    case "agent_version_required"
    {
      return if ( ! exists($json->{"parameters"}{"version"}) );

      if ( $json->{"parameters"}{"version"} eq $VERSION )
      {
        my $hostname = $APPCONFIG->get("HOSTNAME");
        my $net_group = $APPCONFIG->get("NET_GROUP");

        server_send({
          "action" => "agent_register",
          "parameters" => {
            "type" => "snort",
            "hostname" => $hostname,
            "net_group" => $net_group
          }
        });

        $kernel->yield("server_ping") if ( $APPCONFIG->get("PING_DELAY") != 0 )
      }
      else
      {
        # version mismatch
        log_error("Platypus Server requires version " . $json->{"parameters"}{"version"} . " but found " . $VERSION . ".");

        # exit
        $kernel->call($session, "_stop");
      }
    }
    # agent information set
    case "agent_information_set"
    {
      agent_info($json->{"parameters"});
    }
    # agent event received confirmation
    case "agent_event_confirm"
    {
      barnyard2_send("BY2_EVT_CFM", $json->{"parameters"});

      # confirmation indicates the event successfully stored
      $MAX_EID++;
    }
    # agent sensor/event id response
    case "agent_seid_response"
    {
      barnyard2_send("BY2_SEID_RSP", $json->{"parameters"});
    }
    else
    {
      log_error("Unknown command received: " . $json->{"action"});
    }
  }

  return 0;
}

sub server_send
{
  my ($r_data) = @_;
  my $heap = $APPVARS{"HEAP"};

  if ( ref($r_data) ne "HASH" )
  {
    debug($DBG{"BROWSER"}, "Ignoring due to not seeing a HASH REF! (" . ref($r_data) . ")");
    return;
  }

  # append a timestamp
  $r_data->{"timestamp"} = timestamp_now_get();

  # JSON enocde our response
  my $message = encode_json($r_data);

  if ( !$SVR_CONNECTED )
  {
    debug($DBG{"COMMON"}, "Not connected to Platypus server. Unable to send: " . $message);
  }
  else
  {
    debug($DBG{"COMMON"}, "Sending to Platypus server: " . $message);
    $heap->{wheel_svr}->put($message);
  }

  return 0;
}

#
# UTILITY FUNCTIONS/HANDLERS
#

#
#
sub agent_info
{
  my ($json) = @_;

  if ( exists($json->{"id"}) )
  {
    $SENSOR_ID = $json->{"id"};
  }

  if ( exists($json->{"eid_max"}) )
  {
    $MAX_EID = $json->{"eid_max"};
  }
}

#
#
sub daemonize
{
  my $pid = fork();

  if ( ! defined($pid) )
  {
    log_error("Unable to daemonize the server!");
    return;
  }

  if ( $pid )
  {
    log_normal("Daemonizing ... Setting child " . $pid . " free.");
    sleep 1;
    exit;
  }

  POSIX::setsid;

  my $log_file = "/var/log/platypus-server.log";

  # redirect
  log_normal("Logging to: " . $log_file);

  open STDIN, "/dev/null";
  open STDOUT, ">>" . $log_file;
  open STDERR, ">>" . $log_file;
}

#
#
sub usage_display
{
  my $kernel = $APPVARS{"KERNEL"};
  my $session = $APPVARS{"SESSION"};

  printf "Usage: " . $0 . " [-D] -c <filename>\n";
  printf "  -c <filename>  PATH to configuration file\n";
  printf "  -d             Run in Daemon mode\n";
  printf "  -V             Display version information\n";
  printf "  -?             Show this help\n";
  printf "\n";
  printf "Long Options:\n";
  printf "  --debug        Enable debugging mode\n";
  printf "  --version      Same as -V\n";
  printf "  --help         Same as -?\n";

  # exit
  $kernel->call($session, "_stop");
}

sub timestamp_now_get
{
  my ($format) = @_;

  # check if localtime is being enforced
  my $gmt = ( ! ( defined($APPCONFIG) && $APPCONFIG->get("NO_UTC") == 1 ) );

  return timestamp_format(Today_and_Now($gmt), $format);
}

sub timestamp_format
{
  my ($dy, $dm, $dd, $th, $tm, $ts, $format) = @_;

  $format = "%04d-%02d-%02d %02d:%02d:%02d" unless defined($format);

  return sprintf($format, $dy, $dm, $dd, $th, $tm, $ts);
}

sub exit_clean
{
  my $kernel = $APPVARS{"KERNEL"};
  my $session = $APPVARS{"SESSION"};

  # force call to "_stop" to facilitate a clean exit
  $kernel->call($session, "_stop");
}


#
# LOGGING/DEBUGGING FUNCTIONS
#

sub debug
{
  my ($level, $message) = @_;

  # return if debugging is not enabled
  return if ( ! ($APPVARS{"DEBUG"} & $level) );

  # print message along side the current timestamp
  print timestamp_now_get() . " DEBUG: (" . $level . ") " . $message . "\n";
}

sub log_normal
{
  my ($message) = @_;

  # print message along side the current timestamp
  print timestamp_now_get() . " " . $message . "\n";
}

sub log_error
{
  my ($message) = @_;

  # print message along side the current timestamp
  print timestamp_now_get() . " ERROR: " . $message . "\n";
}

sub log_fatal
{
  my ($message) = @_;

  # print message along side the current timestamp
  print timestamp_now_get() . " FATAL: " . $message . "\n";

  # prompt exit
  exit_clean();
}

1;
