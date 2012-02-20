#!/usr/bin/perl

use strict;
use 5.010;

use lib '../lib';
use Test::More 'no_plan';
use Data::Dumper;

use_ok 'NSMF::Model::Session';
use_ok 'NSMF::Model::Event';
my $sess = NSMF::Model::Session->new;
my $evnt = NSMF::Model::Event->new;

isa_ok( $sess, 'NSMF::Model::Session');
isa_ok( $evnt, 'NSMF::Model::Event');

$sess->id('1');
$evnt->id(2);

ok ($sess->id ~~ 1, 'Session should have get/set methods');
ok ($evnt->id == 2, 'Event should have get/set methods');

ok( ref $sess->metadata eq 'HASH', 'Should return metadata');
ok( ref $sess->attributes eq 'ARRAY', 'Should return attributes');;
ok( ref $sess->required_properties eq 'ARRAY', 'Should return required properties');;

ok( ref NSMF::Model::Session->new({ net_dst_port => '22' }) eq 'NSMF::Model::Session', 'Checking object type validation');

#my $sess2 = NSMF::Model->new('session');
#my $sess3 = NSMF::Model->load(session => $id);
