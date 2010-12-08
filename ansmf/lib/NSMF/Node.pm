package NSMF::Node;

use strict;
use warnings;
use POSIX;
use NSMF::Error;
use NSMF::Net;
use NSMF::Auth;
use NSMF::Config;

sub load_config {
    my $path = shift;
    return NSMF::Config::load_config($path);
}

sub connect {
    my ($config) = shift;
    my $conn = NSMF::Net::connect({
	server => $config->{server}, 
        port   => $config->{port},
    });  
   $conn or die "[!!]  Connection Failed!\n";   
}

sub authenticate {
	my $conn = shift;
	my ($config) = @_;
	my $session = qq//;
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
        alarm 10;
        $session = NSMF::Auth::send_auth($conn, $config);
	close $conn;
	alarm 0;
    };
    
    alarm 0;
    if ($@) {
	die("[!! Authentication Failed!\n") unless $@ eq "alarm\n";   # propagate unexpected errors
       print "[!!] Connection Timeout\n";exit;
    } 
    else {
    	return $session;
#    	print "didnt";
          # didn't
    }
}

sub execute {
    my ($config) = @_;
    my $name = $config->{NODENAME};
    eval {
        my $module = "NSMF::Node::$name";
 	require $module;
        $module->import();

    	$module->run;
    };
}

1;
