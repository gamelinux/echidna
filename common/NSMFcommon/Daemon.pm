package NSMFcommon::Daemon;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
use POSIX qw(setsid);
@EXPORT = qw(ALL);
$VERSION = '0.1';

=head2 go_daemon

Takes $LOGFILE,$PIDFILE as input
 - Die if fail
 - Return 0 on success
 
=cut

sub go_daemon {
    my ($LOGFILE,$PIDFILE) = @_;

    # Prepare to meet the world of Daemons
    print "[*] Daemonizing...\n";
    chdir ("/") or die "[E] Failed to chdir /: $!\n";
    open (STDIN, "/dev/null") or die "[E] Failed to open /dev/null: $!\n";
    open (STDOUT, "> $LOGFILE") or die "[E] Failed to open $LOGFILE: $!\n";
    defined (my $dpid = fork) or die "[E] Failed to fork: $!\n";
    if ($dpid) {
       # Write PID file
       # NSMFcommon::Dirs::check_dir_create_w ("/var/run/");
       open (PID, "> $PIDFILE") or die "[E] Failed to open($PIDFILE): $!\n";
       print PID $dpid, "\n";
       close (PID);
       exit 0;
    }
    setsid ();
    open (STDERR, ">&STDOUT");
}

1;
