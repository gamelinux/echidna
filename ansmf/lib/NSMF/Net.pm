package NSMF::Net;

use strict;
use v5.10;
use IO::Socket::INET;
use NSMF::Util;
use Carp qw(croak);
our $VERSION = '0.1';

=head2 connect

 Method for connecting to a nsmf-server via IO::Socekt::INET

=cut

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

=head2 send_data

 Method for sending data to a nsfm server, node, client or worker.

=cut

sub send_data {
    my ($self) = @_;
    print $self->{__data}->{sessions} . "\n";
    return 0;
}

1;


