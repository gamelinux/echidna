#!/usr/bin/perl
#
# This file is part of the NSM framework
#
# Copyright (C) 2010-2012, Edward Fjellskål <edwardfjellskaal@gmail.com>
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
package NSMF::Server::WebSocket;
use warnings;
use strict;

#
# PERL INCLUDES
#
use Carp;
use Digest::MD5 qw(md5);
use POE::Filter::Line;

#
# NSMF INCLUDES
#
use NSMF::Common::Registry;

#
# GLOBAL EXPORTS
#
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(websocket_handshake);

#
# GLOBAL VARIABLES
#
my $logger = NSMF::Common::Registry->get('log') 
    // carp 'Got an empty config object from Registry';

#
# WEBSOCKET ROUTINES
#

#
#
sub websocket_handshake
{
    my ($wheel, $data) = @_;
    my ($resource, $host, $origin, $key1, $key2) = ("", "", "", "", "");

    $logger->debug("WebSocket upgrade request: \n" . $data);

    $resource = $1 if ($data =~ /GET (.*) HTTP/);
    $host = $1 if ($data =~ /Host: (.*)\r\n/);
    $origin = $1 if ($data =~ /Origin: (.*)\r\n/);
    $key1 = $1 if ($data =~ /Sec-WebSocket-Key1: ([^\r\n].*)\r\n/);
    $key2 = $1 if ($data =~ /Sec-WebSocket-Key2: ([^\r\n].*)\r\n/);

    my $challenge_md5 = "";

    my $ws_location = "WebSocket-Location: ";
    my $ws_origin = "WebSocket-Origin: ";

    # check if we have a key challenge
    if ( ($key1 ne "") && ($key2 ne "") ) {
        # build up the clients challenge
        my $challenge = "";
        $challenge .= websocket_key_decode($key1);
        $challenge .= websocket_key_decode($key2);
        $challenge .= substr($data, -8);

        # calculate the challenge md5
        $challenge_md5 = md5($challenge);

        $ws_location = "Sec-" . $ws_location;
        $ws_origin = "Sec-" . $ws_origin;
    }
    else {
        $logger->debug("This is a non-challenge request.");
    }

    # prepare the server response
    my $response = "HTTP/1.1 101 Web Socket Protocol Handshake\r\n" .
                   "Upgrade: WebSocket\r\n" .
                   "Connection: Upgrade\r\n" .
                   $ws_location . "ws://" . $host . $resource . "\r\n" .
                   $ws_origin . $origin . "\r\n" .
                   "\r\n";

    # add the challenge if appropriate
    if ( $challenge_md5 ne "" ) {
        $response .= $challenge_md5;
    }

    websocket_upgrade_connection($wheel, $response);
}

#
#
sub websocket_upgrade_connection
{
    my ($wheel, $response) = @_;

    if ( 1 ) # check wheel
    {
        $logger->debug("Upgrading WebSocket connection with:\n" . $response);

        # push the response back to the client
        $wheel->put($response);

        # once the connection has been upgraded we need to update our filter
        $wheel->set_filter( POE::Filter::Line->new( Literal => chr(0xff) ) );

        # XXX: for some reason we need to send dummy data once connection is opened
        $wheel->put(chr(0x00) . "nullage");
    }
}


#
#
sub websocket_key_decode
{
  my ($key) = @_;

  # set sane default return
  my $ret = "";

  # calculate the spaces
  my $spaces += () = $key =~ /\ /g;

  # extract the number
  $key =~ s/\D//g;

  # no remainder indicates a valid decode
  if ( ($key % $spaces) == 0 )
  {
    # must be in network order (32-bit);
    $ret = pack("N", $key/$spaces);
  }
  else
  {
    $logger->error("Unable to decode the WebSocket security key!");
  }

  return $ret;
}

#TEST VECTOR: 
#    my $test = "GET /demo HTTP/1.1\r\n" .
#               "Connection: Upgrade\r\n" .
#               "Sec-WebSocket-Key2: 12998 5 Y3 1  .P00\r\n" .
#               "Upgrade: WebSocket\r\n" .
#               'Sec-WebSocket-Key1: 4 @1  46546xW%0l 1 5' . "\r\n" .
#               "Origin: http://example.com\r\n" .
#               "\r\n" .
#               "^n:ds[4U";
#

1;
