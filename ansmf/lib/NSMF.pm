package NSMF;

use v5.10;

our @ISA = (NSMF::Util);

use constant DEBUG    => 1;
use constant ACCEPTED => '200 OK ACCEPTED';

our ($VERSION, $PRODUCT) = ('v1', 'The Network Security Monitoring Framework');
1;
