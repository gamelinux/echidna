#!/usr/bin/perl

use strict;
use warnings;

use 5.010;
use lib '../lib';
use Test::More 'no_plan';

my @subs = qw( defined_args trim );
use_ok( 'NSMF::Common::Util', @subs );

ok( 'defined_args', 'Testing if defined_args was loaded' );
ok( 'trim', 'Testing if trim was loaded' );

my $test_string1 = '  Hello World  ';
is( trim($test_string1), 'Hello World', "trim should return a trimmed string");

#my $list1 = [ [ 1 ], [ 2 ], [4]];
#my $list2 = [ [ 1 ], [ 2 ], [3]];
#is_deeply($list1, $list2);


