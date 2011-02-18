package NSMF::Node;

use strict;
use v5.10;

use base qw(NSMF::Action);

# NSMF Imports
use NSMF;
use NSMF::Net;
use NSMF::Comm qw(init);
use NSMF::Auth;
use NSMF::Util;
use NSMF::Config;

# POE Imports
use POE;

# Misc 
use POSIX;
use Data::Dumper;

our $VERSION = '0.1';

# Constructor
sub new {
    my $class = shift;

    bless {
        id          => undef,
    	nodename    => undef,
    	netgroup    => undef,
    	server      => undef,
        port        => undef,
    	secret      => undef,
        config_path => undef,
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

    return unless ref($self) ~~ /NSMF::Node/;
#    return unless $path ~~ /[a-zA-Z0-9-\.]+/;

    my $config = NSMF::Config::load($path);

    $self->{config_path} =  $path;
    $self->{name}        =  ref($self)          // 'NSMF::Node';
    $self->{id}          =  $config->{id}       // '';
    $self->{nodename}    =  $config->{nodename} // '';
    $self->{netgroup}    =  $config->{netgroup} // '';
    $self->{server}      =  $config->{server}   // '0.0.0.0';
    $self->{port}        =  $config->{port}     // '10101';
    $self->{secret}      =  $config->{secret}   // '';
    $self->{__settings}  =  $config->{settings} // {};

    return $config;
}

# Returns actual configuration settings
sub config {
    my ($self) = @_;

    return unless ref($self) ~~ /NSMF::Node/;
    
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

   NSMF::Comm::init( $self );  
}

# Returns the actual session
sub session {
    my ($self) = @_;

    return unless ref($self) ~~ /NSMF::Node/;
    return $self->{__handlers}->{_sessid};
}

sub id {
    my ($self, $arg) = @_;
    $self->{id} = $arg if defined_args($arg);
    return $self->{id};
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
    POE::Kernel->run();
}

1;
