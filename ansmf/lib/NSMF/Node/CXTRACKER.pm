package NSMF::Node::CXTRACKER;

use strict;
use base qw(NSMF::Node);
use NSMF::Util;
use v5.10;

sub run {
    my ($self) = @_;
    
    return unless  $self->{__handlers}->{_sess_id};
    print_status("Running cxtracker processing..");
}

1;
