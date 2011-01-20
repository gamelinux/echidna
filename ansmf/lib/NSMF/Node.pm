package NSMF::Node;

use strict;
use v5.10;
use POSIX;
use Carp qw(croak);
use NSMF::Util;
use NSMF::Error;
use NSMF::Net;
use NSMF::Comm;
use NSMF::Auth;
use NSMF::Config;
use Class::Accessor "antlers";
use Data::Dumper;
our $VERSION = '0.1';

# Class::Accessor generated get/set methods
has id       => ( is => "rw");
has nodename => ( is => "rw");
has netgroup => ( is => "rw");
has server   => ( is => "rw");
has port     => ( is => "rw");
has secret   => ( is => "rw");

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
    	}
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
    $self->{id}          =  $config->{id}       // 'ID';
    $self->{nodename}    =  $config->{nodename} // 'NODENAME';
    $self->{netgroup}    =  $config->{netgroup} // 'NETGROUP';
    $self->{server}      =  $config->{server}   // '127.0.0.1';
    $self->{port}        =  $config->{port}     // '10101';
    $self->{secret}      =  $config->{secret}   // 'SHA256SECRET';

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

# Connect method
sub connect {
   my ($self) = @_;

   return unless defined_args($self->server, $self->port);

   my $conn = NSMF::Net::connect({
	    server => $self->server, 
        port   => $self->port
   });  

   $self->{__handlers}->{_net} = $conn;

   return $self->{__handlers}->{_net};   
}

sub connect_ng {

   my ($self) = @_;

   return unless defined_args($self->server, $self->port);

   my $conn = NSMF::Comm::connect( $self->server, $self->port);  

   return $conn;
}

# Returns the actual session
sub get_session {
    my ($self) = @_;

    return unless ref($self) ~~ /NSMF::Node/;
    return $self->{__handlers}->{_sessid};
}

# Authentication method
# Returns the session id or 0 if authentication fails. 
sub authenticate {
    my ($self) = @_;

    return unless ref($self) ~~ /NSMF::Node/;
    my $session = qq//;

    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm 10;
        $session = NSMF::Auth::send_auth(
                       $self->{__handlers}->{_net}, 
                       { 
                           id       => $self->id, 
                           server   => $self->server, 
                           secret   => $self->secret, 
                           nodename => $self->nodename, 
                           netgroup => $self->netgroup, 
                       }
                   );
	    alarm 0;
    };

    alarm 0;

    if ($@) {
	    croak("[!! Authentication Failed!") unless $@ eq "alarm\n";   # propagate unexpected errors
        print_error "Connection Timeout";exit;
    } 
    else {
        $self->{__handlers}->{_sessid} = $session;
        croak "Authentication Failed." if $session ~~ 0;

    	return $self->{__handlers}->{_sessid};
    }
}

# Synchronization method.
# Uses $self->connect and $self->authenticate.
# Returns the session.
sub sync {
    my ($self) = @_;

    return 0 unless ref($self) ~~ /NSMF::Node/;

    if ( $self->connect() ) {
        return $self->authenticate();
    }
    
    return;
}

1;
