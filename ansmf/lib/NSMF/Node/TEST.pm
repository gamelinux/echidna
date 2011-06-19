package NSMF::Node::TEST;

use strict;
use v5.10;

# NSMF::Node Subclass
use base qw(NSMF::Node);

# NSMF Imports
use NSMF;
use NSMF::Util;

# POE Imports
use POE;

# Misc
use Data::Dumper;

our $VERSION = '0.1';

# These are POE elements that help us interact with the POE Kernel and Heap storage
#my ($kernel, $heap);


# Here is your main()
sub run {
    my ($self, $kernel, $heap) = @_;

    # This provides the necessary data to the Node module for use of the put method
    $self->register($kernel, $heap);

    # At this point the Node is already authenticated so we can begin our work
    print_status("Running test processing..");
 
    say "    -> Sending Custom PING";
    $self->ping();
}

1;
