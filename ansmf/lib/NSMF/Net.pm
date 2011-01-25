package NSMF::Net;

use strict;
use v5.10;
use IO::Socket::INET;
use Carp qw(croak);
our $VERSION = '0.1';

=head2 connect

 Method for connecting to a nsmf-server via IO::Socekt::INET

=cut

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

=head2 send_data

 Method for sending data to a nsfm server, node, client or worker.

=cut

sub send_data {
    my ($data) = @_;

}

1;


