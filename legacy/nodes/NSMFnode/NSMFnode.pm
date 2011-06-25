package NSMFnode::State;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@EXPORT = qw(save_state load_state);
$VERSION = '0.1';

sub save_state {
    my ($DEBUG, $STATEFILE,$POS) = @_;
    if(-l $STATEFILE) {
        die("$statefile is a symbolic link, refusing to touch it.");
    }
    open (OUT, ">$STATEFILE") or exit 4;
    print OUT "$POS\n";
    close OUT;
    return 1; # OK
}

sub load_state {
    # Inputs:
    # debug = 1
    # statefile = /var/lib/nsmframework/state/<module>.state
    my ($DEBUG, $STATEFILE) = @_;
    my $pos   = undef;
    
    if (-f "$STATEFILE") {
        open (IN, "$STATEFILE") or exit 4;
        if (<IN> =~ /^(\d+)/) {
            $pos = $1;
        }
        close IN;
    }
    return $pos;
    # return of undef means that it has no value!
}


if (!defined $pos)
{
    # Initial run.
    $pos = $startsize;
}

if ($startsize < $pos)
{
    # Log rotated
    parseLogfile ($rotlogfile, $pos, (stat $rotlogfile)[7]);
    $pos = 0;
}

parseLogfile ($logfile, $pos, $startsize);
$pos = $startsize;

if ( $ARGV[0] and $ARGV[0] eq "config" )
{
    print "graph_title Postfix bytes throughput\n";
    print "graph_args --base 1000 -l 0\n";
    print "graph_vlabel bytes / \${graph_period}\n";
    print "graph_scale  yes\n";
    print "graph_category  postfix\n";
    print "volume.label throughput\n";
    print "volume.type DERIVE\n";
    print "volume.min 0\n";
    exit 0;
}

print "volume.value $volume\n";

if(-l $statefile) {
    die("$statefile is a symbolic link, refusing to touch it.");
}               
open (OUT, ">$statefile") or exit 4;
print OUT "$pos:$volume\n";
close OUT;

sub parseLogfile 
{    
    my ($fname, $start, $stop) = @_;
    open (LOGFILE, $fname) or exit 3;
    seek (LOGFILE, $start, 0) or exit 2;

    while (tell (LOGFILE) < $stop) 
    {
    my $line =<LOGFILE>;
    chomp ($line);

    if ($line =~ /qmgr.*from=.*size=([0-9]+)/) 
    {
        $volume += $1;
    } 
    }
    close(LOGFILE);    
}

# vim:syntax=perl
