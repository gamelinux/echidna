package NSMF::Service::Database::Base;

use strict;
use 5.010;

sub search { die "Override with custom implementation" }
sub update { die "Override with custom implementation" }
sub insert { die "Override with custom implementation" }
sub delete { die "Override with custom implementation" }

1;
