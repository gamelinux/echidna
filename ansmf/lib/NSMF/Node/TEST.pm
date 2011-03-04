package NSMF::Node::TEST;

use strict;
use v5.10;

# NSMF::Node Subclass
use base qw(NSMF::Node);

# NSMF Imports
use NSMF;
use NSMF::Net;
use NSMF::Util;

# POE Imports
use POE;

# Misc
use Data::Dumper;
our $VERSION = '0.1';

# These are POE elements that help us interact with the POE Kernel and Heap storage
#my ($kernel, $heap);

sub new {
    my $class = shift;
    my $node = $class->SUPER::new;
    $node->{__data} = {};

    return $node;
}

# Here is your main()
sub run {
    my ($self, $kernel, $heap) = @_;

    # This provides the necessary data to the Node module for use of the put method
    $self->register($kernel, $heap);

    # At this point the Node is already authenticated so we can begin our work
    print_status("Running test processing..");

    # Hello world!
    $self->hello();

    # PUT is our send method, reuses the $heap->{server}->put that we provided to the super class with the $self->register method
    print_status("Sending a custom ping!");
    $self->put("PING " .time(). " NSMF/1.0");
    $self->put('POST ' .time(). ' NSMF/1.0' . "\nMYDATA");
}

sub  hello {
    print_status "Hello World from TEST Node!";
}
1;
