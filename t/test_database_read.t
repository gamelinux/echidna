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
   debug => 1,
};

my $db = NSMF::Service::Database->new(dbi => $settings);
my $dbh = $db->fetch;
isa_ok( $dbh, 'AnyEvent::DBI');
$db->return_handle($dbh);

my $sessions = $db->search(session => { time_start => '2012-12-12 12:12:12', non_existent => 'asd' })->recv;
ok( ref $sessions eq 'ARRAY', 'Sessions result should be an array');
ok( ref $sessions->[0] eq 'HASH', 'Session results should be hashref')
    if @$sessions > 0;

my $cv = AE::cv;

# enabling object mapping
$db->map_objects(1);
$db->search(session => { net_dst_port => '22' }, sub {
    my $sessions = shift;
    ok( ref $sessions->[0] eq 'NSMF::Model::Session', 'Session result should be an object')
        if @$sessions > 0;
    $cv->send(scalar @$sessions);
});

$cv->recv;
