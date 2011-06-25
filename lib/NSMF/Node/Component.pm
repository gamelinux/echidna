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
package NSMF::Node::Component;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Node::Action);

#
# PERL INCLUDES
#
use Carp;
use Compress::Zlib;
use Data::Dumper;
use MIME::Base64;
use POE;

#
# NSMF INCLUDES
#
use NSMF::Common::Logger;
use NSMF::Node;
use NSMF::Node::Config;
use NSMF::Node::Core qw(init);
use NSMF::Util;

#
# GLOBALS
#
our $VERSION = '0.1';
our ($poe_kernel, $poe_heap);
my $logger = NSMF::Common::Logger->new();

# Constructor
sub new {
    my $class = shift;

    bless {
        agent       => undef,
        nodename    => undef,
        netgroup    => undef,
        server      => undef,
        port        => undef,
        secret      => undef,
        config_path => undef,
        __data      => {},
        __handlers => {
            _net     => undef,
            _db      => undef,
            _sessid  => undef,
        },
        __settings => undef,
    }, $class;
}

# Public Interface to load config as pair of names and values
sub load_config {
    my ($self, $path) = @_;

    my $package = __PACKAGE__;
    return unless ref($self) ~~ /$package/;
#    return unless $path ~~ /[a-zA-Z0-9-\.]+/;

    my $config = NSMF::Node::Config::load($path);

    $self->{config_path} =  $path;
    $self->{name}        =  ref($self)          // 'NSMF::Node::Component';
    $self->{agent}       =  $config->{agent}    // '';
    $self->{nodename}    =  $config->{nodename} // '';
    $self->{netgroup}    =  $config->{netgroup} // '';
    $self->{server}      =  $config->{server}   // '0.0.0.0';
    $self->{port}        =  $config->{port}     // '10101';
    $self->{secret}      =  $config->{secret}   // '';
    $self->{__settings}  =  $config->{settings} // {};

    $logger->verbosity(5) if ( defined($logger) && $config->{settings}{debug} > 0 );

    return $config;
}

# Returns actual configuration settings
sub config {
    my ($self) = @_;

    return if ( ref($self) ne __PACKAGE__ );

    return {
        id       => $self->id,
        nodename => $self->nodename,
        server   => $self->server,
        port     => $self->port,
        netgroup => $self->netgroup,
        secret   => $self->secret,
    };
}

sub sync {
   my ($self) = @_;

   return unless  defined_args($self->server, $self->port);
   NSMF::Node::Core::init( $self );
}

sub register {
    my ($self, $kernel, $heap) = @_;
    $poe_kernel = $kernel;
    $poe_heap   = $heap;
}
# Send Data function
# Requires $poe_heap to be defined with the POE HEAP
# Must be used only after run() method has been executed.
sub put {
    my ($self, $data) = @_;

    return unless ref $poe_heap;

    $poe_heap->{server}->put($data);
}

sub ping {
    my ($self) = @_;
    return unless ref $poe_heap;

    my $payload = 'PING ' .time(). ' NSMF/1.0' ."\r\n";
    $poe_heap->{server}->put($payload);
}

sub post {
    my ($self, $type, $data) = @_;

   if (ref $type) {
       my %hash = %$type;
       $type = keys %hash;
       $data = $hash{$type};
   }
   my @valid_types = qw(
        pcap
        cxt
    );
    croak 'POST Data Type Not Supported'
        unless $type ~~ @valid_types;

    croak 'POE HEAP Instance Not Found'
        unless ref $poe_heap;

    srand (time ^ $$ ^ unpack "%L*", `ps axww | gzip -f`);
    $logger->debug('   [*] Data Size: ' . length($data));

    my $payload = 'POST ' .$type. ' ' . int(rand(10000)). " NSMF/1.0\n\n" .encode_base64($data);

    $poe_heap->{server}->put($payload);
}

# Returns the actual session
sub session {
    my ($self) = @_;

    return if ( ref($self) ne __PACKAGE__ );
    return $self->{__handlers}->{_sessid};
}

sub agent {
    my ($self, $arg) = @_;
    $self->{agent} = $arg if defined_args($arg);
    return $self->{agent};
}

sub nodename {
    my ($self, $arg) = @_;
    $self->{nodename} = $arg if defined_args($arg);
    return $self->{nodename};
}

sub netgroup {
    my ($self, $arg) = @_;
    $self->{netgroup} = $arg if defined_args($arg);
    return $self->{netgroup};
}

sub server {
    my ($self, $arg) = @_;
    $self->{server} = $arg if defined_args($arg);
    return $self->{server};
}

sub port {
    my ($self, $arg) = @_;
    $self->{port} = $arg if defined_args($arg);
    return $self->{port};
}

sub secret {
    my ($self, $arg) = @_;
    $self->{secret} = $arg if defined_args($arg);
    return $self->{secret};
}

sub start {
    POE::Kernel->run;
}
1;
