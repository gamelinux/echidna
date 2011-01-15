package NSMF::Node::CXTRACKER;

use strict;
use v5.10;
use base qw(NSMF::Node);
use NSMF::Util;
our $VERSION = '0.1';

sub run {
    my ($self) = @_;
    
    return unless  $self->get_session;
    print_status("Running cxtracker processing..");
}

1;
