package NSMF::Node::CXTRACKER;

use strict;
use v5.10;

# NSMF::Node Subclass
use base qw(NSMF::Node);

# NSMF Imports
use NSMF;
use NSMF::Net;
use NSMF::Util;

# POE Imports
use POE;
use POE::Component::DirWatch;

# Misc
use Data::Dumper;
our $VERSION = '0.1';
our $cxtdir;

my $poe_heap;

sub new {
    my $class = shift;
    my $node = $class->SUPER::new;
    $node->{__data} = {};

    return $node;
}

sub  hello {
    say "Hello from CXTRACKER Node!!";
}
sub run {
    my ($self, $kernel, $heap) = @_;
     
    $poe_heap = $heap; 
    print_status("Running cxtracker processing..");

    $cxtdir = $self->{__settings}->{cxtdir};
    my $watcher = $self->watcher($cxtdir, '_process');

    $self->start();
}

# Send Data function
# Requires $poe_heap to be defined with the POE HEAP
# Must be used only after run() method has been executed.
sub put {
    my ($data) = @_;

    return unless $poe_heap;

    $poe_heap->{server}->put($data);
}

sub _process {
    my ($self, $file) = @_;

    my $cxtdir = $self->{__settings}->{cxtdir};

    print_error 'CXTDIR undefined!' unless $cxtdir;

    my @FILES;
    if( -r -w -f $file ) {
        push( @FILES, $file );
    }

    my ($sessions, $start_time, $end_time, $process_time, $result);

    foreach my $file ( @FILES ) {

        say "[*] Found file: $file";

        $start_time   = time();
        $sessions     = _get_sessions($file);
        $end_time     = time();
        $process_time = $end_time - $start_time;

        say "[*] File $file processed in $process_time seconds" if (NSMF::DEBUG);

        $start_time   = $end_time;
        $result       = $self->put($sessions);
        $end_time     = time();
        $process_time = $end_time - $start_time;

        if ($result == 0) {
            print "[*] Session record sent in $process_time seconds" if (NSMF::DEBUG);
        }

        say "[W] Deleting file: $file";
        unlink($file) or print_error "Failed to delete $file";
    }
}

=head2 _get_sessions

 This sub extracts the session data from a session data file.
 Takes $file as input parameter.

=cut

sub _get_sessions {
    my $sfile = shift;
    my $sessions_data = qq();

    if (open (FILE, $sfile)) {
        if (NSMF::DEBUG) {
            my $filelen=`wc -l $sfile |awk '{print \$1'}`;
            my $filesize=`ls -lh $sfile |awk '{print \$5}'`;

            chomp $filelen;
            chomp $filesize;

            say "[*] File:$sfile, Lines:$filelen, Size:$filesize";
        }

        # Verify the data in the session files
        LINE:
        while (my $line = readline FILE) {
            chomp $line;
            $line =~ /^\d{19}/;
            unless($line) {
                warn "[*] Error: Not valid session start format in: '$sfile'";
                next LINE;
            }
            my @elements = split/\|/,$line;
            unless(@elements == 15) {
                warn "[*] Error: Not valid Nr. of session args format in: '$sfile'";
                next LINE;
            }
            # Things should be OK now to send to the SERVER
            if ( $sessions_data eq "" ) {
                $sessions_data = "$line";
            } else {
                $sessions_data = "$sessions_data\n$line";
            }
      }

      close FILE;
      say "Sessions data:\n$sessions_data" if NSMF::DEBUG;
      return $sessions_data;
      }
}

1;
