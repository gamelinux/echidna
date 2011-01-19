package NSMF::Config;

use strict;
use v5.10;
use NSMF::Util;
use NSMF::Error;
use YAML::Tiny;
our $VERSION = '0.1';

sub load {
    my ($file) = @_;
    my $config;

    return unless ( -e -r $file);

    given($file){
        when(/^.+\.yaml$/) {
            $config = load_yaml($file);
        }
        when(/^.+\.conf$/) {
            $config = load_config($file);
        }
        default: {
            $config = load_yaml($file);
        }
    }

    return $config;
}

sub load_yaml {
    my ($file) = @_;
    
    my $yaml = YAML::Tiny->read($file);

    my $server = $yaml->[0]->{server};
    my $node   = $yaml->[0]->{node};
  
    return unless defined_args($server, $node);
  
    # Server Checking


    # Node Checking   
    
    return {
        id        => $node->{id},
	    nodename  => $node->{nodename},
    	netgroup  => $node->{netgroup},
    	secret    => $node->{secret},
    	server    => $node->{server},
      	port      => $node->{port},
    };
}

sub load_config {
    my ($file) = @_;

    my $config = {};
    if(not -r "$file"){
        warn "[W] Config '$file' not readable\n";
        return $config;
    }
    open(my $FH, "<",$file) or die "[E] Could not open '$file': $!\n";
    while (my $line = <$FH>) {
        chomp($line);
        $line =~ s/\#.*//;
        next unless($line); # empty line
        # EXAMPLE=/something/that/is/string/repesented
        if (my ($key, $value) = ($line =~ m/(\w+)\s*=\s*(.*)$/)) {
           warn "[W] Read keys and values from config: $key:$value\n" if NSMF::DEBUG > 0;
           $config->{$key} = $value;
        }else {
          die "[E] Not valid configfile format in: '$file'";
        }
    }
    close $FH;
    return $config;
}

sub check_config {  
    my $config = shift;
    my @KEYS = qw(id nodename netgroup secret server port);

    foreach my $key (@KEYS) {
        not_defined("$key") unless grep $_ eq $key, @KEYS and defined $config->{$key};
    }

    return 1;
}

1;

=head2 load 

Read the yaml configuration file and loads variables.

=cut

=head2 load_config

Reads the configuration file and loads variables.
Takes a config file and NSMF::DEBUG as input, and returns a hash of config options.

=cut

