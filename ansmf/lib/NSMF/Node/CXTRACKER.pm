package NSMF::Node::CXTRACKER;

use strict;
use base qw(NSMF::Node);
use v5.10;

sub run {
    my ($self) = @_;
    
    return unless  $self->{__handlers}->{_sess_id};

    say "Running cxtracker processing..";
}

1;
