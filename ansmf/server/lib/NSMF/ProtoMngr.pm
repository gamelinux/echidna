package NSMF::ProtoMngr;

use v5.10;
use strict;

use NSMF;

sub create {
    my ($self, $type) = @_;
    
    $type //= 'HTTP';
    my $proto_path = 'NSMF::Proto::' .( uc $type);
    my @protocols = NSMF->protocols; 
    if ( $proto_path ~~ @protocols) {
        eval "use $proto_path";
        die 'Failed to Load Protocol' if $@;
        
        return $proto_path->instance;
    }
    else {
        die 'Protocol Not Supported';
    }
}

1;
