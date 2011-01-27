package NSMF::Communication;

use v5.10;
use strict;
use base qw(Exporter);
our @EXPORT = qw(put);

sub put {
    my ($heap, $data) = @_;

    $heap->{client}->put($data . "\r\n");
}

1;
