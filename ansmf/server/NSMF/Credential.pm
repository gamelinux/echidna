package NSMF::Credential;

use NSMF::Driver;

use base qw(Data::ObjectDriver::BaseObject);
__PACKAGE__->install_properties({
    columns => ['id', 'nodename', 'password'],
    datasource => 'credential',
    primary_key => 'id',
    driver => NSMF::Driver->driver,
});
