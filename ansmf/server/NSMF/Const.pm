package NSMF::Const;

use v5.10;
use strict;
use base qw(Exporter);
our @EXPORT = qw(AUTH_REQUEST);

use constant AUTH_REQUEST => '^AUTH ([A-Z]+) NSMF\/1.0$';
  
    my $AUTH_REQUEST = '^AUTH ([A-Z]+) NSMF\/1.0$';
    my $ID_REQUEST   = '^ID ([[:alnum:]])+ ([[:alnum:]])+ NSMF\/1.0$';
    my $PING_REQUEST = '^PING ([[:alnum:]])+ NSMF\/1.0$';

1;
