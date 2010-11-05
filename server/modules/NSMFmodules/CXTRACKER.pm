package NSMFmodules::CXTRACKER;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@EXPORT = qw(ALL);
$VERSION = '0.1';

sub CXTRACKER {
    my $REQ = shift;
    print "[*] Huston - we got packet! Best regards, your CXTRACKER module!\n";
    undef $REQ;
    return;
}

1;
