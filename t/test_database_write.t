#!/usr/bin/perl 

use strict;
use 5.010;

use lib '../lib';
use Data::Dumper;
use Test::More 'no_plan';
use AnyEvent;

use NSMF::Model::Session;
use_ok 'NSMF::Service::Database';

my $settings = {
   driver    => 'mysql',
   user      => 'nsmf',
   database  => 'nsmf',
   password  => 'passw0rd.',
   pool_size => 1,
   debug     => 1,
};

my $db = NSMF::Service::Database->new(dbi => $settings);

my $session = NSMF::Model::Session->new({
        id                    => 101010101,
        node_id               => 1,
        time_start            => '2012-12-12 12:12:12',
        time_end              => '2012-12-12 12:12:12',
        net_src_ip            => '2130706433',
        net_src_port          => '220',
        net_dst_ip            => '2130706433',
        net_dst_port          => '22',
        net_protocol          => '6',
        net_src_total_bytes   => '10',
        net_dst_total_bytes   => '10',
        net_src_total_packets => '1',
        net_dst_total_packets => '2',
        timestamp     => '121231212',
        time_duration => '1',
        net_version   => '4',
        net_src_flags => '1',
        net_dst_flags => '1',
        data_filename => 'text',
        data_offset   => '',
        data_length   => '10',
        meta          => '',
});


my $cv = AE::cv;

#$db->insert(session => $session, sub {
#    say "Session Inserted";
#});


$db->update(session => { id => 101010101 }, { data_length => 11, asd => "asdfa" }, sub {
    say "Update Done";
    $cv->send;
});

$cv->recv;
