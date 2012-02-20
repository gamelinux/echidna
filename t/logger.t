#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use lib '../lib';
use Test::More 'no_plan';

use_ok('NSMF::Common::Logger');

my $logger = NSMF::Common::Logger->new;
my @subs = qw( new load debug info error fatal warn );
isa_ok($logger, 'NSMF::Common::Logger');
can_ok($logger, @subs);

