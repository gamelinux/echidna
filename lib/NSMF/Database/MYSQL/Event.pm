package NSMF::Database::MYSQL::Event;

use strict;
use 5.010;

my $model = 'NSMF::Model::Event';

sub get_max_id {
    my ($self, $db, $args, $cb) = @_;

    my $where = '';

    if ( defined($args->{node_id} ) )
    {
      $where = ' WHERE node_id=' . $args->{node_id};
    }

    $db->execute_query("SELECT * FROM event" . $where . " ORDER BY id DESC LIMIT 1", $model, sub {
        $cb->(@_);
    });
}

sub create_definition {
    my ($self, $db) = @_;

    my $sql = q{
        CREATE TABLE IF NOT EXISTS `event` (
            `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
            `timestamp` datetime NOT NULL,
            `classification` smallint(5) unsigned NOT NULL,
            `node_id` bigint(20) unsigned NOT NULL,
            `net_version` int(10) unsigned NOT NULL,
            `net_protocol` tinyint(3) unsigned NOT NULL,
            `net_src_ip` decimal(39,0) NOT NULL,
            `net_src_port` smallint(5) unsigned NOT NULL,
            `net_dst_ip` decimal(39,0) NOT NULL,
            `net_dst_port` smallint(5) unsigned NOT NULL,
            `sig_id` bigint(20) unsigned NOT NULL,
            `sig_revision` bigint(20) unsigned NOT NULL,
            `sig_priority` bigint(20) unsigned NOT NULL,
            `sig_message` text NOT NULL,
            `sig_category` text,
            `meta` text,
            PRIMARY KEY (`id`),
            KEY `node_ix` (`node_id`),
            KEY `signature_ix` (`sig_id`)
        )
    }; 

    $db->execute($sql, sub {
        my ($rs, $err) = @_;

        die "Failed to create table $err" if $err;
    });
}

1;
