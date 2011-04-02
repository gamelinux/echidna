package NSMF::Driver;
use Data::ObjectDriver::Driver::DBI;

sub driver {
    Data::ObjectDriver::Driver::DBI->new(
        dsn      => 'dbi:mysql:nsmf',
        username => 'root',
        password => '$passw0rd..!',
    )
}

1;
