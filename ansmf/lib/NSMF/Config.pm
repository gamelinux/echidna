package NSMF::Config;

use strict;
use NSMF::Error;
use v5.10;
our $VERSION = '0.1';

=head2 load_config

Reads the configuration file and loads variables.
Takes a config file and $DEBUG as input, and returns a hash of config options.

=cut

sub load_config {
    my ($file,$DEBUG) = @_;
    $DEBUG ||= 0;
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
           warn "[W] Read keys and values from config: $key:$value\n" if $DEBUG > 0;
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
    my @KEYS = qw(ID NODENAME NETGROUP SECRET SERVER PORT);

    foreach my $key (@KEYS) {
        not_defined("$key") unless grep $_ eq $key, @KEYS and defined $config->{$key};
    }

    return 1;
}

1;
