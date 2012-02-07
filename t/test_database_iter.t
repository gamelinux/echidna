#!/usr/bin/perl 

use strict;
use 5.010;

use lib '../lib';
use Data::Dumper;
use Test::More 'no_plan';
use AnyEvent;

use_ok 'NSMF::Service::Database';

my $settings = {
   driver => 'mysql',
   user   => 'echidna',
   database => 'echidna',
   password => 'passw0rd.',
   pool_size => 10,
};

my $db = NSMF::Service::Database->new(dbi => $settings);
isa_ok( $db, 'NSMF::Service::Database::DBI' );

$db->map_objects(1); # return NSMF::Model::Session instead of a hashref
$db->window_size(1); # default 100, number of objects fetched

my $iter = $db->search_iter(session => { net_dst_port => 22 });
isa_ok($iter, 'CODE');
my $counter = 0;
while (my $session = $iter->()) {
    isa_ok($session, 'NSMF::Model::Session');
    $counter += 1;
    last if $counter == 3;
}

my $cv = AE::cv;
my $sessions = $db->search(session => { net_dst_port => 22 }, sub { 
    $cv->send(shift);  
#    say Dumper shift->[0];
});
ok( ref $cv->recv eq 'ARRAY', 'DAL + Callback Should return arrayref');
