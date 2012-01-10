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
package NSMF::Agent::Component::BARNYARD2;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Agent::Component);

#
# PERL INCLUDES
#
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use AnyEvent::Util qw(fh_nonblocking AF_INET6);
use Carp;
use Data::Dumper;


use Socket qw(AF_INET AF_UNIX SOCK_STREAM SOCK_DGRAM SOL_SOCKET SO_REUSEADDR);

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
    return "BARNYARD2";
}

sub sync {
    my ($self) = shift;

    $self->SUPER::sync();

    my $settings = $self->{__config}->settings();

    # get barnyard2 listener options with sane defaults
    my ($host, $port) = parse_hostport($settings->{barnyard2}{host} // "127.0.0.1",
                                       $settings->{barnyard2}{port} // 7060);

    $self->{eid_max} = -1;

    $self->{__server} = tcp_server(
        $host, $port,
        sub { $self->barnyard2_accept(@_); },
        sub { $self->barnyard2_prepare(@_); }
    );
}

sub run {
    my $self = shift;

    $self->logger->debug('Running barnyard2 processing...');
}

#
# BARNYARD2 FUNCTIONS/HANDLERS
#

sub barnyard2_prepare {
    my ($self, $handle, $listen_host, $listen_port) = @_;

    $self->logger->info('Listening for barnyard2 instances on ' . $listen_host . ':' . $listen_port);
}

sub barnyard2_accept {
    my ($self, $handle, $remote_host, $remote_port) = @_;

    my $session = $remote_host . '-' . $remote_port;

    $self->logger->debug('SESSION: '. $session, "HANDLE: " . fileno( $handle ) );

    $self->{__session} = AnyEvent::Handle->new(
        fh => $handle,
        on_error => sub { $self->barnyard2_error(@_); },
        on_read  => sub { $self->barnyard2_read(@_); },
        on_eof   => sub { $self->barnyard2_closed(@_); }
    );


    $self->logger->debug('Barnyard2 instance connected: ' . $remote_host);
}

sub barnyard2_error {
    my ($self) = @_;

}

sub barnyard2_read {
    my ($self, $handle) = @_;

    $handle->push_read( line => sub { $self->barnyard2_dispatcher(@_); } );
}

sub barnyard2_write {
    my ($self, $data) = @_;

#    return if( ! defined($self->{__session}) );

    say("PUSHING: $data");
    $self->{__session}->push_write($data . "\n");
}

sub barnyard2_closed {
    my ($self) = @_;

}

sub barnyard2_dispatcher
{
    my ($self, $handle, $data) = @_;

    my $logger = NSMF::Common::Registry->get('log')
        // carp 'Got an empty logger object in barnyard2_dispatcher';

    # there is no point processing if we're not connected to the server
    # NOTE:
    # the benefit of not processing is that barnyard2 will block on input
    # processing and thus will take care of all caching overhead.
    return if( ! $self->connected() );

    # ignore any empty string artefacts
    return if( length($data) == 0 );

    # clean up any leading \0 which are artefacts of banyard2's C string \0 terminators
    if ( ord(substr($data, 0, 1)) == 0 ) {
        $data = substr($data, 1);
    }

    my @data_tabs = split(/\|/, $data);

    $logger->debug('Received from barnyard2: ' . $data . ' (' . @data_tabs . ')');

    given($data_tabs[0]) {
        # agent sensor/event id request
        when("BY2_SEID_REQ") {
            # no need to push to server if our cache is valid
            return if ( $self->{__node_id} <= 0 );

            if( $self->{eid_max} < 0 ) {
                $self->barnyard2_eid_max_get();
                return;
            }

            $self->barnyard2_write('BY2_SEID_RSP|' . $self->{__node_id} . '|' . $self->{eid_max});
        }
        # alert event
        when(/^BY2_EVT|BY2_EVENT|EVENT/) {
            # forward to server
            my @tmp_data = @data_tabs[1..$#data_tabs];
            $self->{__proto}->post('barnyard2.save', \@tmp_data, sub {
                my $json = shift;

                $logger->debug($json, $self->{eid_max});

                if( defined($json->{result}) &&
                    $json->{result} == ($self->{eid_max}+1) )
                {
                    $logger->debug('Sending confirmation');
                    $self->barnyard2_write('BY2_EVT_CFM|' . $json->{result});
                    $self->{eid_max}++;
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
    my $self = shift;

    # on-forward the node id if we have it
    if( $self->{__node_id} > 0 ) {
        $self->{__proto}->post('barnyard2.get_max_eid', {}, sub {
            my $json = shift;

            # set up the cache and push to barnyard2 now
            if( defined($json->{result}) )
            {
                $self->{eid_max} = $json->{result} + 0;
            }
        });
    }
}



#
# ENHANCED SERVER
#

# used in cases where we may return immediately but want the
# caller to do stuff first
sub _postpone {
   my ($cb, @args) = (@_, $!);

   my $w; $w = AE::timer 0, 0, sub {
      undef $w;
      $! = pop @args;
      $cb->(@args);
   };
}

sub tcp_server_general
{
  my ($host, $service, $accept, $prepare) = @_;

  $host = $AnyEvent::PROTOCOL{ipv4} < $AnyEvent::PROTOCOL{ipv6} && AF_INET6
          ? "::" : "0"
    unless defined $host;

  # name/service to type/sockaddr resolution
  resolve_sockaddr $host, $service, 0, 0, undef, sub {
    my @target = @_;

    my %state = ( fh => undef );

    $state{next} = sub {
      return unless exists $state{fh};

      my $target = shift @target;
#        or return _postpone sub {
#          return unless exists $state{fh};
#          %state = ();
#          $connect->();
#        };

      my ($af, $type, $proto, $sockaddr) = @$target;

      # win32 perl is too stupid to get this right :/
      Carp::croak "tcp_server/socket: address family not supported"
        if AnyEvent::WIN32 && $af == AF_UNIX;

      socket $state{fh}, $af, SOCK_STREAM, 0
        or Carp::croak "tcp_server/socket: $!";

      if ($af == AF_INET || $af == AF_INET6) {
        setsockopt $state{fh}, SOL_SOCKET, SO_REUSEADDR, 1
          or Carp::croak "tcp_server/so_reuseaddr: $!"
            unless AnyEvent::WIN32; # work around windows bug
      } elsif ($af == AF_UNIX) {
        unlink $proto;
      }

      bind($state{fh}, $sockaddr) or Carp::croak "bind: $!";

      fh_nonblocking $state{fh}, 1;

      my $len;

      if ($prepare) {
        my ($service, $host) = unpack_sockaddr( getsockname($state{fh}) );
        $len = $prepare && $prepare->($state{fh}, format_address($host), $service);
      }

      $len ||= 128;

      listen $state{fh}, $len
        or Carp::croak "listen: $!";

      $state{aw} = AE::io $state{fh}, 0, sub {
        # this closure keeps $state alive
        while ($state{fh} && (my $peer = accept my $fh, $state{fh})) {
          fh_nonblocking $fh, 1; # POSIX requires inheritance, the outside world does not

          my ($service, $host) = unpack_sockaddr $peer;
          $accept->($fh, format_address $host, $service);
        }
      };

      defined wantarray
      ? guard { %state = () } # clear fh and watcher, which breaks the circular dependency
        : ()
    }
  }
}

1;
