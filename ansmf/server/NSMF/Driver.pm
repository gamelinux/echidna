package NSMF::Driver;
use Data::ObjectDriver::Driver::DBI;

sub driver {
    Data::ObjectDriver::Driver::DBI->new(
        dsn      => 'dbi:mysql:openfpc',
        username => 'openfpc',
        password => 'openfpc',
    )
}

1;
