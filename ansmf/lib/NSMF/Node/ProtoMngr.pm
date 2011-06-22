package NSMF::Node::ProtoMngr;

use v5.10;
use strict;

use NSMF::Node;

sub create {
    my ($self, $type) = @_;

    $type //= 'JSON';
    my $proto_path = 'NSMF::Node::Proto::' . uc($type);

    my @protocols = NSMF->protocols;
    if ( $proto_path ~~ @protocols ) {
        eval "use $proto_path";
        if ( $@ ) {
            die { status => 'error', message => 'Failed to Load Protocol ' . $@ };
        }

        return $proto_path->instance();
    }
    else {
        die { status => 'error', message => 'Protocol Not Supported.' };
    }
}

1;
