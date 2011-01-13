package NSMF::Node;

use strict;
use v5.10;
use POSIX;
use Carp qw(croak);
use NSMF::Error;
use NSMF::Net;
use NSMF::Auth;
use NSMF::Config;
use Class::Accessor "antlers";
use Data::Dumper;

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
        id         => undef,
    	nodename   => undef,
    	netgroup   => undef,
    	server     => undef,
        port       => undef,
    	secret     => undef,
    	__handlers => {
	    	_net     => undef,
    		_db      => undef,
            _sess_id => undef,
    	}
    }, $class;
}

# Public Interface to load config as pair of names and values
sub load_config {
    my ($self, $path) = @_;
    my $config = NSMF::Config::load_config($path);

    $self->{name}     ||=  ref($self);
    $self->{id}       ||=  $config->{ID};
    $self->{nodename} ||=  $config->{NODENAME};
    $self->{netgroup} ||=  $config->{NETGROUP};
    $self->{server}   ||=  $config->{SERVER};
    $self->{port}     ||=  $config->{PORT};
    $self->{secret}   ||=  $config->{SECRET};

    return $config;
}

sub check_self {
}

sub connect {
   my ($self) = @_;
   my $conn = NSMF::Net::connect({
	    server => $self->server, 
        port   => $self->port,
   });  

   #die "[!!]  Connection Failed!\n" unless $conn;
   return unless $conn;

   $self->{__handlers}->{_net} = $conn;

   return $self->{__handlers}->{_net};   
}

sub session {
    my ($self) = @_;
    return $self->{__handlers}->{_sess_id};
}

sub authenticate {
    my ($self) = @_;
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
	    die("[!! Authentication Failed!\n") unless $@ eq "alarm\n";   # propagate unexpected errors
        print "[!!] Connection Timeout\n";exit;
    } 
    else {
        say "[+] Authenticated..";
        $self->{__handlers}->{_sess_id} = $session;
    	return $self->{__handlers}->{_sess_id} // 0;
    }
}

sub sync {
    my ($self) = @_;

    return 0 unless ref($self);

    if ( $self->connect() ) {
        return $self->authenticate();
    }
    
    return 0;
}

1;
