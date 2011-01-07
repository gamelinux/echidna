package NSMF::Node;

use strict;
use warnings;
use POSIX;
use NSMF::Error;
use NSMF::Net;
use NSMF::Auth;
use NSMF::Config;

require Exporter;
#our @EXPORT = qw/load_config connect authenticate execute/;

sub new {
    my $class = shift;
    bless {
        config => undef,
	conn => undef,
	session => undef,
    }, $class;
}

sub load_config {
    my ($self, $path) = @_;

    $self->{config} = NSMF::Config::load_config($path);
    return NSMF::Config::load_config($path);
}

sub connect {
    my ($self) = @_;
    my $conn = NSMF::Net::connect({
	server => $self->{config}->{SERVER}, 
        port   => $self->{config}->{PORT},
    });  
   die "[!!]  Connection Failed!\n" unless $conn;
   $self->{conn} = $conn;   
}

sub session {
    my ($self) = @_;
    return $self->{session} if $self->{session};
}

sub authenticate {
    my ($self) = @_;
    my $session = qq//;

    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm 10;
        $session = NSMF::Auth::send_auth($self->{conn}, $self->{config});
	alarm 0;
    };
    
    alarm 0;
    if ($@) {
	die("[!! Authentication Failed!\n") unless $@ eq "alarm\n";   # propagate unexpected errors
       print "[!!] Connection Timeout\n";exit;
    } 
    else {
        print "[+] Authenticated..\n";
        $self->{session} = $session;
    	return $session;
    }
}

sub execute {
    my ($self) = @_;
    my $name = $self->{config}->{NODENAME};
    print $name,"\n";
    eval {
        my $module = "NSMF::Node::$name";
 	require $module;
        $module->import();
    	$module->run;
    };

    if ($@) {
        die "[!!] Could not execute code for ", $self->{config}->{NODENAME};
    }
}

1;
