package NSMF::Node;

use NSMF::Driver;
use Cache::Memcached;
use Data::ObjectDriver::Driver::Cache::Memcached;

use v5.10;
use Data::Dumper;

use base qw(Data::ObjectDriver::BaseObject);

__PACKAGE__->install_properties({
    columns => [
            'id', 
            'nodename', 
            'host', 
            'module_type',
            'network',
            'interface',
            'description',
            'bpf_filter',
            'first_seen',
            'last_seen',
            'ip',
            'key'
    ],
    datasource => 'node',
    primary_key => 'id',
    driver => NSMF::Driver->driver,
});

sub hello {
    my $self = shift;
    say "hi!";
}
