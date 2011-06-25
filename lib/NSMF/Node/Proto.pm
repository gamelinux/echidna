package NSMF::Proto;

use strict;
use v5.10;

sub dispatcher {
    die { status => 'error', message => 'Dispatcher requires to be overridden'};
}

1;
