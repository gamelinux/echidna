#!/usr/bin/perl

use strict;
use warnings;
use 5.010;

use Test::More 'no_plan';

use_ok('NSMF::Common::Logger');

my $logger = NSMF::Common::Log->new;
my @subs = qw( new load debug info error fatal warn );
isa_ok($logger, 'NSMF::Common::Log');
can_ok($logger, @subs);

