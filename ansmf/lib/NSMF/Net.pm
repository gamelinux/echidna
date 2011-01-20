package NSMF::Net;

use strict;
use v5.10;
use IO::Socket::INET;
use Carp qw(croak);
our $VERSION = '0.1';

sub connect {
    my ($config) = shift;
    my $NSMFSERVER = $config->{server} // '127.0.0.1';
    my $NSMFPORT   = $config->{port}   // 10101;
    my $PROTO      = $config->{proto}  // 'tcp';

    my $socket = IO::Socket::INET->new(
        PeerAddr => $NSMFSERVER, 
	    PeerPort => $NSMFPORT, 
        Proto    => $PROTO,
    );

    return $socket // croak "Could not create connection at server $config->{server}:$config->{port}";
}

1;


