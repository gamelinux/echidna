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
   type    => 'mysql',
   user      => 'nsmf',
   name  => 'nsmf',
   pass  => 'passw0rd.',
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
$cv->begin;
#$cv->begin;
#$db->insert(session => $session, sub {
#    my ($result, $error) = @_;

#    if ($error) { say "Got an Error: $error\n\n\n\n" }
#    say Dumper $result;
#    $cv->end;
#});

#say "\n\n\n\n\n\n";

$db->update(node => { id => 2 }, {state => 0, description => " "});

$cv->recv;
exit;

my $sql = '
CREATE TABLE session4 
        id                     BIGINT UNSIGNED    NOT NULL ,
        timestamp              DATETIME           NOT NULL ,
        time_start             DATETIME           NOT NULL ,
        time_end               DATETIME           NOT NULL ,
        time_duration          BIGINT UNSIGNED    NOT NULL ,
        node_id                BIGINT UNSIGNED    NOT NULL ,
        net_version            INT UNSIGNED       NOT NULL ,
        net_protocol           TINYINT UNSIGNED   NOT NULL ,
        net_src_ip             DECIMAL(39)        NOT NULL ,
        net_src_port           SMALLINT UNSIGNED  NOT NULL ,
        net_src_total_packets  BIGINT UNSIGNED    NOT NULL ,
        net_src_total_bytes    BIGINT UNSIGNED    NOT NULL ,
        net_src_flags          TINYINT UNSIGNED   NOT NULL ,
        net_dst_ip             DECIMAL(39)        NOT NULL ,
        net_dst_port           SMALLINT UNSIGNED  NOT NULL ,
        net_dst_total_packets  BIGINT UNSIGNED    NOT NULL ,
        net_dst_total_bytes    BIGINT UNSIGNED    NOT NULL ,
        net_dst_flags          TINYINT UNSIGNED   NOT NULL ,
        data_filename_start    TEXT               NOT NULL ,
        data_offset_start      BIGINT UNSIGNED    NOT NULL ,
        data_filename_end      TEXT               NOT NULL ,
        data_offset_end        BIGINT UNSIGNED    NOT NULL ,
        meta                   TEXT,
        PRIMARY KEY (id),
        INDEX node_ix (node_id)
    )';

$db->do($sql, sub { 
    my ($result, $error) = @_;

    if (defined $error) {
        say "Something failed! $error";
    }

    $cv->end;
});

#$db->do("SELECT SLEEP(1)", sub {
#    $cv->end;
#});
$cv->recv;
