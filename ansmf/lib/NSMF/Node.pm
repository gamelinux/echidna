package NSMF;

use strict;
use v5.10;

use Module::Pluggable search_path => 'NSMF::Node::Proto', sub_name => 'protocols';

our ($VERSION, $PRODUCT) = ('v1', 'The Network Security Monitoring Framework');
our $DEBUG = 1;

1;
