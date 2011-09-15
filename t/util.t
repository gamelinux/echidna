#!/usr/bin/perl

use strict;
use warnings;

use 5.010;
use lib '../lib';
use Test::More 'no_plan';

my @subs = qw( defined_args trim );
use_ok( 'NSMF::Common::Util', @subs );

my @subs = qw( defined_args trim );
can_ok( 'NSMF::Common::Util', @subs);

