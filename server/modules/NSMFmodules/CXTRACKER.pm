package NSMFmodules::CXTRACKER;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@EXPORT = qw(CXTRACKER);
$VERSION = '0.1';

sub CXTRACKER {
    my $REQ = shift;
    print "[*] Huston - we got packet! Best regards, your CXTRACKER module!\n" if $REQ->{'debug'};
    put_cxdata_to_db($REQ);
    undef $REQ;
    return;
}

=head2 put_cxdata_to_db

 This module processes the data from the cxtracker node
 and inserts it to the nsmf-server database.

=cut

sub put_cxdata_to_db {

    

}

1;
