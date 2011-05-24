package NSMF::ProtoFactory;

use v5.10;
use strict;

use NSMF::Proto::HTTP;
use NSMF::Proto::JSON;

sub create {
  my $self = shift;
  my $type = shift // "HTTP";
                  
  return NSMF::Proto::HTTP->instance() if ( lc($type) eq "http");
  return NSMF::Proto::JSON->instance() if ( lc($type) eq "json");
}

1;
