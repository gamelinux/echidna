package NSMF::Module::CXTRACKER;

use strict;
use v5.10;

use base qw(NSMF::Module);

sub run {  
    my ($self) = @_;
    $self->hello();
}

sub hello {
    say "Hello World from CXTRACKER Module!!";
}

1;
