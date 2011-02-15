package NSMF::Node::CXTRACKER;

use strict;
use v5.10;
use base qw(NSMF::Node);
use NSMF;
use NSMF::Net;
use NSMF::Util;
use Data::Dumper;
use POE;
use POE::Component::DirWatch;

our $VERSION = '0.1';
our $cxtdir;

sub new {
    my $class = shift;
    my $node = $class->SUPER::new;
    $node->{__data} = {};

    return $node;
}

sub run {
    my ($self) = @_;
     
    print_status("Running cxtracker processing..");

    $cxtdir = $self->{__settings}->{cxtdir};

    my $watcher = $self->watcher($cxtdir, '_process');
}

sub _process {
    my ($self, $file) = @_;

    my $cxtdir = $self->{__settings}->{cxtdir};
    my @FILES;
    if( -r -w -f "$file" ) {
        push( @FILES, $file );
    }

    foreach my $file ( @FILES ) {
        my $starttime=time();
        print "[*] Found file: $file\n";# if ($DEBUG);

        #$self->{__data}->{sessions} = _get_sessions($file);
        push @{$self->{__data}->{sessions}}, split "\n", _get_sessions($file);
        say Dumper $self->{__data}->{sessions};
        say $self->{__data}->{sessions}[0];
        my $endtime=time();
        my $processtime=$endtime-$starttime;
        print "[*] File $file processed in $processtime seconds\n" if (NSMF::DEBUG);
    
        for my $record (@{$self->{__data}->{sessions}}) {
            $starttime=$endtime;
            my $result = $self->put($record);
            $endtime=time();
            $processtime=$endtime-$starttime;
            if ($result == 0) {
                print "[*] Session record sent in $processtime seconds\n" if (NSMF::DEBUG);
            }
        }
        delete $self->{__data}->{sessions};
        print "[W] Deleting file: $file\n";
        unlink($file) or print_error "Failed to delete $file";
    }
        
}

=head2 _get_sessions

 This sub extracts the session data from a session data file.
 Takes $file as input parameter.

=cut

sub _get_sessions {
    my $sfile = shift;
    my $sessionsdata = qq();

    if (open (FILE, $sfile)) {
        if (NSMF::DEBUG) {
            my $filelen=`wc -l $sfile |awk '{print \$1'}`;
            my $filesize=`ls -lh $sfile |awk '{print \$5}'`;
            chomp $filelen;
            chomp $filesize;
            print "[*] File:$sfile, Lines:$filelen, Size:$filesize\n";
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
            if ( $sessionsdata eq "" ) {
                $sessionsdata = "$line";
            } else {
                $sessionsdata = "$sessionsdata\n$line";
            }
      }
      close FILE;
      print "Sessions data:\n$sessionsdata\n" if NSMF::DEBUG;
      return $sessionsdata;
      }
      
}

1;
