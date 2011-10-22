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
use Carp;
use POE;
use POE::Component::Server::TCP;

#
# NSMF INCLUDES
#
use NSMF::Common::Util;

use NSMF::Agent;
use NSMF::Agent::Action;

sub type {
    return "BARNYARD2";
}

sub hello {
    my ($self) = shift;
    $self->logger->debug('Hello from BARNYARD2 node!!');
}

sub sync {
    my ($self) = shift;
    $self->SUPER::sync();

    my $settings = $self->{__config}->settings();

    # get barnyard2 listener options with sane defaults
    my $host = $settings->{barnyard2}{host} // "localhost";
    my $port = $settings->{barnyard2}{port} // 7060;
    #my $self->logger = NSMF::Common::Registry->get('log') 
    #    // 'Fetching logger object for Barnyard Sync';
    
    $self->{__barnyard2} = new POE::Component::Server::TCP(
        Alias         => 'by2',
        Address       => $host,
        Port          => $port,
        ClientConnected => sub {
            my ($kernel, $session, $heap) = @_[KERNEL, SESSION, HEAP];

            $self->logger->debug('Barnyard2 instance connected: ' . $heap->{remote_ip});

            # collect the node ID and max event ID if possible
            $heap->{node_id} = $kernel->call('node', 'ident_node_get');
            $heap->{eid_max} = -1;
            $kernel->yield('barnyard2_eid_max_get');
        },
        ClientDisconnected => sub {
        },
        ClientInput => sub {
            my ($kernel, $response) = @_[KERNEL, ARG0];

            $kernel->yield('barnyard2_dispatcher', $response);
        },
        ClientFilter  => "POE::Filter::Line",
        ObjectStates => [
            $self => [ 'run', 'barnyard2_dispatcher', 'barnyard2_eid_max_get' ]
        ],
        Started => sub {
            $self->logger->info('Listening for barnyard2 instances on ' . $host . ':' . $port);
        },
    );
}

sub run {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $self = shift;

    $self->logger->debug("Running barnyard2 processing..");

    $self->hello();
}

#
# BARNYARD2 FUNCTIONS/HANDLERS
#

sub barnyard2_dispatcher
{
    my ($kernel, $heap, $data) = @_[KERNEL, HEAP, ARG0];

    my $logger = NSMF::Common::Registry->get('log')
        // carp 'Got an empty logger object in barnyard2_dispatcher';
    
    # there is no point processing if we're not connected to the server
    # NOTE:
    # the benefit of not processing is that barnyard2 will block on input
    # processing and thus will take care of all caching overhead.
    my $connected =  $kernel->call('node', 'connected') // 0;

    if( $connected == 0 ) {
        return;
    }

    # ignore any empty string artefacts
    if ( length($data) == 0 ) {
        return;
    }

    # clean up any leading \0 which are artefacts of banyard2's C string \0 terminators
    if ( ord(substr($data, 0, 1)) == 0 ) {
        $data = substr($data, 1);
    }

    my @data_tabs = split(/\|/, $data);

    $logger->debug("Received from barnyard2: " . $data . " (" . @data_tabs . ")");

    given($data_tabs[0]) {
        # agent sensor/event id request
        when("BY2_SEID_REQ") {
            # no need to push to server if our cache is valid
            if ( $heap->{node_id} != -1 &&
                 $heap->{eid_max} != -1 )
            {
                $heap->{client}->put("BY2_SEID_RSP|" . $heap->{node_id} . "|" . $heap->{eid_max});
            }
            else
            {
                # collect the node id as appropriate
                if ( $heap->{node_id} == -1 ) {
                  $heap->{node_id} = $kernel->call('node', 'ident_node_get');
                }

                $kernel->yield('barnyard2_eid_max_get');
            }
        }
        # alert event
        when(/^BY2_EVT|BY2_EVENT|EVENT/) {
            # forward to server
            my @tmp_data = @data_tabs[1..$#data_tabs];
            $kernel->post('node', 'post', {
                "action" => "event_alert",
                "parameters" => \@tmp_data
            }, sub {
                my ($s, $k, $h, $json) = @_;

                $logger->debug($json, $heap->{eid_max});

                if( defined($json->{result}) &&
                    $json->{result} == ($heap->{eid_max}+1) )
                {
                    $logger->debug('Sending confirmation');
                    $heap->{client}->put('BY2_EVT_CFM|' . $json->{result});
                    $heap->{eid_max}++;
                }
            });
        }
        default {
            $logger->error("Unknown barnyard2 command: \"" . $data_tabs[0] . "\" (" . length($data_tabs[0]) . ")");
        }
    }
}

sub barnyard2_eid_max_get
{
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $self = shift;

    # on-forward the node id if we have it
    if ( $heap->{node_id} != -1 ) {
        $kernel->post('node', 'post', {
            action => 'node_max_eid_get',
            parameters => {
                node_id => $heap->{node_id}
            }
        }, sub {
            my ($s, $k, $h, $json) = @_;

            # set up the cache and push to barnyard2 now
            if( defined($json->{result}) )
            {
                $heap->{eid_max} = $json->{result} + 0;
            }
        });
    }
}

1;
