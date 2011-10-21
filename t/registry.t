#!/usr/bin/perl 

use strict;
use 5.010;
use lib '../lib';

use Test::More 'no_plan';

# require
use_ok("NSMF::Common::Registry");

my $reg = NSMF::Common::Registry->new;

# instance and methods
isa_ok($reg, 'NSMF::Common::Registry');
can_ok($reg, qw( new instance get can ));
can_ok('NSMF::Common::Registry', qw( get can ));

my $data = { 
    email => 'windkaiser@gmail.com',
    age => -1
};

ok( $reg->set( eddie => $data), 'Set Check');

# should throw a warning
ok( ! $reg->set( 1234 => $data), 'Not Numbers Check');
ok( ! $reg->set( qwe12 => $data), 'Only Characters as Name Check');

# singleton as object or directly from the class name
is_deeply( $reg->get('eddie'), $data, 'Get Common Value Check');

# direct class get
is_deeply( NSMF::Common::Registry->get('eddie'), $data, 'Direct Structure Value Check');

# should throw a warning
ok( ! $reg->get('nonexistentname'), 'Nonexistent Value Check' );
ok( ! $reg->get(), 'Get Empty Value Check');
ok( ! $reg->set(), 'Set Empty Value Check');
ok( ! $reg->set('name'), 'Set Empty Value 2 Check');
