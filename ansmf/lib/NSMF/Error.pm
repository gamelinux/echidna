package NSMF::Error;

use strict;
use base 'Exporter';
our @EXPORT=qw(not_defined);

sub not_defined {
    my $message = shift;
    print(" Error: Directive '$message' not defined in config.\n");
    exit;
}

1;
