#!/usr/bin/perl 

use strict;
use 5.010;

use lib '../lib';
use Data::Dumper;
use Test::More 'no_plan';
use AnyEvent;

use_ok 'NSMF::Service::Database';

my $settings = {
   type => 'mysql',
   user => 'echidna',
   name => 'echidna',
   pass => 'passw0rd.',
   pool_size => 10,
   debug => 1,
};

my $db = NSMF::Service::Database->new(dbi => $settings);
my $dbh = $db->fetch;
isa_ok( $dbh, 'AnyEvent::DBI');
$db->return_handle($dbh);

my $cv = AE::cv;

# enabling object mapping
$db->map_objects(1);
$db->search(session => { net_dst_port1 => '22' }, sub {
    my ($sessions, $error) = @_;
    
    if ($error) {
        say "Got Error: $error";
        exit;
    }
    ok( ref $sessions->[0] eq 'NSMF::Model::Session', 'Session result should be an object')
        if @$sessions > 0;
    #$cv->send(scalar @$sessions);
    $cv->send;
});

$cv->recv;
