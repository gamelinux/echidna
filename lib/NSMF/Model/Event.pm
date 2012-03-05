package NSMF::Model::Event;

use strict;
use 5.010;

use base qw(NSMF::Model::Object);

__PACKAGE__->set_properties({
    id             => ['int'],
    node_id        => ['int'],
    net_src_ip     => ['ip'],
    net_src_port   => ['int'],
    net_dst_ip     => ['ip'],
    net_dst_port   => ['int'],
    net_protocol   => ['int'],

    timestamp      => 'timestamp',
    classification => 'text',
    net_version    => 'int',
    sig_id         => 'int',
    sig_revision   => 'int', 
    sig_priority   => 'int',
    sig_message    => 'text',
    sig_category   => 'text',
    meta           => 'text',
});

1;

