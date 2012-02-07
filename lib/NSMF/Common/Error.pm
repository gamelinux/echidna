package NSMF::Common::Error;

use strict;

use Carp;
use base qw(Exporter Class::Accessor);
__PACKAGE__->mk_accessors(qw(error message));

our @EXPORT = qw(
    throw
);

sub throw {
    my ($exception, $message) = @_;

    croak $exception unless $message;

    croak __PACKAGE__->new({ error => $exception, message => $message });
}

1;
