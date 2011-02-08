package NSMF::Credential;

use NSMF::Driver;
use Cache::Memcached;
use Data::ObjectDriver::Driver::Cache::Memcached;

use base qw(Data::ObjectDriver::BaseObject);
__PACKAGE__->install_properties({
    columns => ['id', 'nodename', 'password'],
    datasource => 'credential',
    primary_key => 'id',
#    driver      => Data::ObjectDriver::Driver::Cache::Memcached->new(
#        cache => Cache::Memcached->new({ servers => [ '127.0.0.1:11211']}),
#        fallback => NSMF::Driver->driver,
#    ),
    driver => NSMF::Driver->driver,
});
