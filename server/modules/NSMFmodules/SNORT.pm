package NSMFmodules::SNORT;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@EXPORT = qw(SNORT);
$VERSION = '0.1';

sub SNORT {
    my $REQ = shift;
    print "[*] Huston - we got packet! Best regards, your SNORT module!\n" if $REQ->{'debug'};
    #my @events = put_snortdata_to_db($REQ);
    #for each client that has connected - push updates (realtime)
    #update_clients_snort($events);
    undef $REQ;
    return;
}

1;
