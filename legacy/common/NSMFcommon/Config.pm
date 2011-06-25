package NSMFcommon::Config;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@EXPORT = qw(ALL);
$VERSION = '0.1';

=head2 load_config

Reads the configuration file and loads variables.
Takes a config file and $DEBUG as input, and returns a hash of config options.

=cut

sub load_config {
    my ($file,$DEBUG) = @_;
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

1;
