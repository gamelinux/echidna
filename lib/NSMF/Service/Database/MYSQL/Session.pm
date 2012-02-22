package NSMF::Service::Database::MYSQL::Session;

use strict;
use 5.010;

use Data::Dumper;
my $model = 'NSMF::Model::Session';

# function for demostration purpose
sub longest_session {
    my ($self, $db, $args, $cb) = @_;

    $db->execute_query("SELECT * FROM session ORDER BY time_duration DESC LIMIT 1", $model, sub {
        $cb->(@_);
    });
}

sub create_definition {
    my ($self, $db) = @_;

    my $sql = q{
        CREATE TABLE IF NOT EXISTS `session` (
            `id` bigint(20) unsigned NOT NULL,
            `timestamp` datetime NOT NULL,
            `time_start` datetime NOT NULL,
            `time_end` datetime NOT NULL,
            `time_duration` bigint(20) unsigned NOT NULL,
            `node_id` bigint(20) unsigned NOT NULL,
            `net_version` int(10) unsigned NOT NULL,
            `net_protocol` tinyint(3) unsigned NOT NULL,
            `net_src_ip` decimal(39,0) NOT NULL,
            `net_src_port` smallint(5) unsigned NOT NULL,
            `net_src_total_packets` bigint(20) unsigned NOT NULL,
            `net_src_total_bytes` bigint(20) unsigned NOT NULL,
            `net_src_flags` tinyint(3) unsigned NOT NULL,
            `net_dst_ip` decimal(39,0) NOT NULL,
            `net_dst_port` smallint(5) unsigned NOT NULL,
            `net_dst_total_packets` bigint(20) unsigned NOT NULL,
            `net_dst_total_bytes` bigint(20) unsigned NOT NULL,
            `net_dst_flags` tinyint(3) unsigned NOT NULL,
            `data_filename` text NOT NULL,
            `data_offset` bigint(20) unsigned NOT NULL,
            `data_length` bigint(20) unsigned NOT NULL,
            `meta` text,
            PRIMARY KEY (`id`),
            KEY `node_ix` (`node_id`)
        )
    };
    $db->execute($sql, sub {});
}

1;
