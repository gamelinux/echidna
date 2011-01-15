package NSMF::Error;

use strict;
use v5.10;
use base 'Exporter';
our @EXPORT = qw(not_defined);
our $VERSION = '0.1';

sub not_defined {
    my $message = shift;
    print(" Error: Directive '$message' not defined in config.\n");
    exit;
}

1;
