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
package NSMF::Agent::Proto::HTTP;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Compress::Zlib;
use Data::Dumper;
use MIME::Base64;
use POE;

#
# NSMF INCLUDES
#
use NSMF::Common::Util;
use NSMF::Common::Registry;

#
# GLOBALS
#
my $instance;
my $logger = NSMF::Common::Registry->get('log') 
    // carp 'Got an empty config object from Registry';

sub instance {
    unless ($instance) {
        my ($class) = @_;
        return bless({}, $class);
    }

    return $instance;
}

sub states {
    my ($self) = @_;

    return if ( ref($self) ne __PACKAGE__ );

    return [
        'dispatcher',

        ## Authentication
        'authenticate',
        'identify',

        # -> To Server
        'send_ping',
        'send_pong',

        # -> From Server
        'got_ping',
        'got_pong',
    ];
}

sub dispatcher {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    $logger->warn("  [error] Response is Empty") if ( ! defined($request) );

    my $action = '';
    given($heap->{stage}) {
        when(/REQ/) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED/i) { 
                    $action = 'identify';
                    $logger->debug('  [response] = OK ACCEPTED'); }
                when(/^NSMF\/1.0 UNAUTHORIZED/i) { 
                    $logger->debug('  [response] = NOT ACCEPTED'); 
                    return; }
                default: {
                    $logger->debug(" UNKNOWN RESPONSE: $request");
                    return; }
            }
        }
        when(/SYN/i) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED/i) { 
                    $heap->{stage} = 'EST';
                    $logger->debug('  [response] = OK ACCEPTED');
                    $kernel->yield('run');
                    $kernel->delay(ping => 3);
                    return; }
                when(/^NSMF\/1.0 401 UNSUPPORTED/i) { 
                    $logger->debug('  [response] = UNSUPPORTED'); 
                    return; }
                default: {
                    $logger->debug(" UNKNOWN RESPONSE: $request");
                    return; }
            }
        }
        when(/EST/i) {
            given($request) {
                when(/^NSMF\/1.0 200 OK ACCEPTED\r\n$/i) {
                     $logger->debug('  -> EST ACCEPTED');
                }
                when(/^PONG (\d)+ NSMF\/1.0\r\n$/i) {
                    $action = 'got_pong'; }
                when(/^PING (\d)+ NSMF\/1.0\r\n$/i) {
                    $action = 'got_ping'; }
                when(/POST/i) {
                    my $req = parse_request(post => $request);
    
                    unless (ref $req eq 'POST') {
                        $logger->debug('Failed to parse');
                        return;
                    }
                    my $data = uncompress(decode_base64( $req->{data} ));
                    $logger->debug('Method: ' . $req->{method});
                    $logger->debug('Params: ' . $req->{param});
                    $logger->debug(Dumper($data)); 
                    }
                default: {
                    $logger->debug(" UNKNOWN RESPONSE: $request");
                    $logger->debug(Dumper($request));
                    return; }
            }
        }
    }

    $kernel->yield($action) if $action;
}
################ AUTHENTICATE ###################
sub authenticate {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    $heap->{stage} = 'REQ';
    my $agent    = $heap->{agent};
    my $secret   = $heap->{secret};

    my $payload = "AUTH $agent $secret NSMF/1.0";
    $heap->{server}->put($payload);
}

sub identify {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    my $nodename = $heap->{nodename};
    my $payload = "ID " .$nodename. " NSMF/1.0";

    $logger->debug('-> Identifying ' .$nodename);
    $logger->fatal('Nodename, Secret not defined on Identification Stage') if ( ! defined_args($nodename) );

    $heap->{stage} = 'SYN';     
    $heap->{server}->put("ID $nodename NSMF/1.0");
}

################ END AUTHENTICATE ##################

################ KEEP ALIVE ###################
sub send_ping {
    my ($kernel, $heap) = @_[KERNEL, HEAP];

    return if $heap->{shutdown};

    # Verify Established Connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('    -> Sending PING...');

    my $ping_sent = time();
    $heap->{server}->put("PING " .$ping_sent. " NSMF/1.0\r\n");
    $heap->{ping_sent} = $ping_sent;
}

sub send_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return if ( $heap->{stage} ne 'EST' );

    my $ping_time = time();
    $heap->{server}->put("PONG " .$ping_time. " NSMF/1.0\r\n");
    $logger->debug('    -> Sending PONG...');
    $heap->{ping_sent} = $ping_time;
}

sub got_ping {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('    <- Got PING ');
    $heap->{ping_recv} = time();

    $kernel->yield('send_pong');
}

sub got_pong {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];

    # Verify Established Connection
    return if ( $heap->{stage} ne 'EST' );

    $logger->debug('    <- Got PONG ');
    $heap->{pong_recv} = time();

    $kernel->delay(send_ping => 60);
}

################ END KEEP ALIVE ###################

sub parse_request {
    my ($type, $input) = @_;

    if (ref $type) {
        my %hash = %$type;
        $type = keys %hash;
        $input = $hash{$type};
    }
    my @types = (
        'auth',
        'get',
        'post',
    );

    return unless grep $type, @types;
    return unless defined $input;

    my @request = split /\s+/, $input;
    given($type) {
        when(/AUTH/i) { 
            return bless { 
                method   => $request[0],
                nodename => $request[1],
                netgroup => $request[2],
                tail     => $request[3],
            }, 'AUTH';
        }
        when(/GET/i) {
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                query  => $request[4] // undef,
            }, 'POST';
        }
        when(/POST/i) {
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                data   => $request[4] // undef,
            }, 'POST';
        }
    }
}

1;
