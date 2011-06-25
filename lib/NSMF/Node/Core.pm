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
package NSMF::Node::Core;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES

use POE;
use POE::Filter::Stream;
use POE::Component::Client::TCP;
use Carp qw(croak);
use Data::Dumper;

#
# NSMF INCLUDES
#
use NSMF::Node;
use NSMF::Node::ProtoMngr;
use NSMF::Common::Logger;
use NSMF::Util;

#
# GLOBALS
#
my $self;
my $proto;
my $logger = NSMF::Common::Logger->new();

eval {
  $proto = NSMF::Node::ProtoMngr->create("JSON");
};

if ( $@ )
{
  $logger->error(Dumper($@));
}

sub init {

    ($self) = @_;
    my ($server, $port) = ($self->server, $self->port);

    $logger->error('Host or Port not defined.') if ( ! defined_args($server, $port) );

    POE::Component::Client::TCP->new(
        RemoteAddress => $server,
        RemotePort    => $port,
        Filter        => "POE::Filter::Stream",
        Connected => sub {
            $logger->info("[+] Connected to $server:$port ...");

            $_[HEAP]->{nodename} = $self->nodename;
            $_[HEAP]->{netgroup} = $self->netgroup;
            $_[HEAP]->{secret}   = $self->secret;
            $_[HEAP]->{agent}    = $self->agent;

            $_[KERNEL]->yield('authenticate');
        },
        ConnectError => sub {
            $logger->info("Could not connect to $server:$port ...");
        },
        ServerInput => sub {
            my ($kernel, $response) = @_[KERNEL, ARG0];
            
            $kernel->yield(dispatcher => $response);
        },
        ServerError => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            $logger->info("Lost connection to server...");
            $logger->info("Going Down");
            exit;
        },
        ObjectStates => [
            $proto => $proto->states(),
        ],
        InlineStates => {
            run => \&run,
        }
    );
}

sub run {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    $logger->debug('-> Calling run');
    $self->run($kernel, $heap);
}

1;
