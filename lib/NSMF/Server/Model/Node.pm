package NSMF::Server::Model::Node;

use v5.10;

use NSMF::Server::Driver;
use Cache::Memcached;
use Data::ObjectDriver::Driver::Cache::Memcached;
use NSMF::Common::Logger;

use Data::Dumper;

use base qw(Data::ObjectDriver::BaseObject);

my $logger = NSMF::Common::Logger->new();

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
    driver => NSMF::Server::Driver->driver(),
});

sub hello {
    my $self = shift;
    $logger->info("hi!");
}
