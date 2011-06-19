package NSMF::Config;

use strict;
use v5.10;
use NSMF::Util;
use Carp qw(croak);
use YAML::Tiny;
our $VERSION = '0.1';

sub load {
    my ($file) = @_;
    my $config;

    croak 'Error opening configuration file. Check read access.' unless ( -e -r $file);

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

    return $config // croak "Could not parse configuration file.";
}

sub load_yaml {
    my ($file) = @_;
    
    my $yaml = YAML::Tiny->read($file);

    my $server = $yaml->[0]->{server};
    my $node   = $yaml->[0]->{node};
    my $settings = $yaml->[0]->{settings};
  
    return unless defined_args($server, $node);
  
    # Server Checking

    # Node Checking   
    
    # Other Checking

    return {
        agent     => $node->{agent},
        nodename  => $node->{nodename},
        netgroup  => $node->{netgroup},
        secret    => $node->{secret},
        server    => $server->{server},
        port      => $server->{port},
        settings  => $settings,
    };
}

sub load_config {
    my ($file) = @_;

    my $config = {};
    if(not -r "$file"){
        warn "[W] Config '$file' not readable\n";
        return $config;
    }
    open(my $FH, "<",$file) or croak "[E] Could not open '$file': $!";
    while (my $line = <$FH>) {
        chomp($line);
        $line =~ s/\#.*//;
        next unless($line); # empty line
        # EXAMPLE=/something/that/is/string/repesented
        if (my ($key, $value) = ($line =~ m/(\w+)\s*=\s*(.*)$/)) {
           warn "[W] Read keys and values from config: $key:$value\n" if NSMF::DEBUG > 0;
           $config->{$key} = $value;
        }else {
          croak "[E] Not valid configfile format in: '$file'";
        }
    }
    close $FH;
    return $config;
}

1;

=head2 load 

Public interface for automatic file configuration reading.

=cut

=head2 load_config

Reads the configuration file and loads variables.
Takes a config file and NSMF::DEBUG as input, and returns a hash of config options.

=head2 load_yaml

Raed the configuration file in yaml format and loads variables.
=cut


