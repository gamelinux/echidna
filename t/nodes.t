#!/usr/bin/perl

use strict;
use 5.010;
use lib '../lib';

use Test::More 'no_plan';

use_ok("NSMF::Agent");

# list of components
my @nodes = qw( cxtracker barnyard2 test );
for my $node (@nodes) {

    my $component_path = "NSMF::Agent::Component::". uc($node);
    use_ok($component_path);
    
    # verifying the type of the object
    my $node_obj = $component_path->new;
    isa_ok($node_obj, $component_path);

    # verifying the methods of the objects
    my @methods = qw/ load_config sync start /;
    can_ok($node_obj, @methods);
}

