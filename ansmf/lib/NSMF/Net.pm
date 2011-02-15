package NSMF::Net;

use strict;
use v5.10;
use IO::Socket::INET;
use NSMF::Util;
our $VERSION = '0.1';

=head2 connect

 Method for connecting to a nsmf-server via IO::Socekt::INET

=cut

sub connect {
    my ($server, $port) = @_;

    print_error "Undefined server/port values." unless defined_args($server ,$port);

    my $proto //= 'tcp';

    my $socket = IO::Socket::INET->new(
        PeerAddr => $server, 
	    PeerPort => $port, 
        Proto    => $proto,
    );

    return $socket // print_error "Could not create connection at server. $server:$port";
}

1;


