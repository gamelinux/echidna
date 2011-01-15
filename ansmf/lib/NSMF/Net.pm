package NSMF::Net;

use strict;
use v5.10;
use IO::Socket::INET;
our $VERSION = '0.1';

sub connect {
    my ($config) = shift;
    my $NSMFSERVER = $config->{server} // '127.0.0.1';
    my $NSMFPORT   = $config->{port}   // 10101;
    my $PROTO      = $config->{proto}  // 'tcp';

    IO::Socket::INET->new(
        PeerAddr => $NSMFSERVER, 
	    PeerPort => $NSMFPORT, 
        Proto    => $PROTO,
    );
}

1;


