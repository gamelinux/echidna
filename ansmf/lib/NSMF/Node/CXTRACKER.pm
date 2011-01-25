package NSMF::Node::CXTRACKER;

use strict;
use v5.10;
use base qw(NSMF::Node);
use NSMF::Util;
our $VERSION = '0.1';

sub new {
    my $class = shift;
    my $node = $class->SUPER::new;
    $node->{__data} = {};
    return $node;
}

sub run {
    my ($self) = @_;
     
    return unless  $self->session;
    print_status("Running cxtracker processing..");
}

1;
