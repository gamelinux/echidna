package NSMF::Net;

use strict;
use v5.10;
use IO::Socket::INET;
use NSMF::Util;
use Carp qw(croak);
our $VERSION = '0.1';

sub connect {
    my ($server, $port) = @_;

    croak "Undefined server/port values." unless defined_args($server ,$port);

    my $proto //= 'tcp';

    my $socket = IO::Socket::INET->new(
        PeerAddr => $server, 
	    PeerPort => $port, 
        Proto    => $proto,
    );

    return $socket // croak "Could not create connection at server. $server:$port";
}

1;


