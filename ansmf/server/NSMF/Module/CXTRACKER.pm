package NSMF::Module::CXTRACKER;

use strict;
use v5.10;

use NSMF::Driver;

use base qw(Data::ObjectDriver::BaseObject);

__PACKAGE__->install_properties({
    columns => [
        'sid', 
        'sessionid', 
        'start_time',
        'end_time',
        'duraction',
        'ip_proto',
        'ip_version',
        'src_ip',
        'src_port',
        'dst_ip',
        'dst_port',
        'src_pkts',
        'src_bytes',
        'dst_pkts',
        'dst_bytes',
        'dst_flags',
    ],
    datasource => 'cxtracker',
    primary_key => 'sessionid',
    driver => NSMF::Driver->driver,
});

sub start {
    say "Start";
}
