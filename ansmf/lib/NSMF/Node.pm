package NSMF::Node;

use strict;
use v5.10;

use base qw(NSMF::Action);

# NSMF Imports
use NSMF;
use NSMF::Core qw(init);
use NSMF::Util;
use NSMF::Config;

use MIME::Base64;
use Compress::Zlib;
# POE Imports
use POE;

# Misc 
use POSIX;
use Data::Dumper;

use Carp;

our $VERSION = '0.1';

our ($poe_kernel, $poe_heap);

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

    return unless ref($self) ~~ /NSMF::Node/;
#    return unless $path ~~ /[a-zA-Z0-9-\.]+/;

    my $config = NSMF::Config::load($path);

    $self->{config_path} =  $path;
    $self->{name}        =  ref($self)          // 'NSMF::Node';
    $self->{agent}       =  $config->{agent}    // '';
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
   NSMF::Core::init( $self );  
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
    say '   [*] Data Size: ' .length $data;
   
    my $payload = 'POST ' .$type. ' ' . int(rand(10000)). " NSMF/1.0\n\n" .encode_base64($data);

    $poe_heap->{server}->put($payload);
}

# Returns the actual session
sub session {
    my ($self) = @_;

    return unless ref($self) ~~ /NSMF::Node/;
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
