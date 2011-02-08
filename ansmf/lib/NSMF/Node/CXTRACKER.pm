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

sub new {
    my $class = shift;
    my $node = $class->SUPER::new;
    $node->{__data} = {};
    return $node;
}

sub run {
    my ($self) = @_;
     
    return unless  $self->session;
    print_status("Running cxtracker processing..");
    $self->dir_watch();
    POE::Kernel->run;
}

sub dir_watch {
    my ($self) = @_;

    my $watcher = POE::Component::DirWatch->new(
        alias => ref($self),
        directory => '/var/lib/cxtracker',
        filter => sub { 
        	-f $_[0];
        },
        file_callback => sub {
    	my ($file) = @_;
            $self->_process($file);    	
        },
        interval => 1,
    );
}

sub _process {
    my ($self, $file) = @_;
    my $cxtdir = $self->{__settings}->{cxtdir};
    my $DEBUG = NSMF::DEBUG;

    my @FILES;
    if( -r -w -f "$file" ) {
        push( @FILES, $file );
    }

    foreach my $file ( @FILES ) {
        my $starttime=time();
        print "[*] Found file: $cxtdir/$file\n";# if ($DEBUG);

        $self->{__data}->{sessions} = _get_sessions($file);
        my $endtime=time();
        my $processtime=$endtime-$starttime;
        print "[*] File $cxtdir/$file processed in $processtime seconds\n" if ($DEBUG);
        $starttime=$endtime;
                #my $result = send_data_to_server($DEBUG,$sessionsdata,$SS);
        my $result = $self->put($self->{__data}->{sessions});
        $endtime=time();
        $processtime=$endtime-$starttime;
        if ($result == 0) {
            print "[*] Session data sent in $processtime seconds\n" if ($DEBUG);
            print "[W] Deleting file: $file\n";
            unlink($file) or print_error "Failed to delete $cxtdir/$file";
            delete $self->{__data}->{sessions};
        }
    }
        
}

=head2 _get_sessions

 This sub extracts the session data from a session data file.
 Takes $file as input parameter.

=cut

sub _get_sessions {
    my $sfile = shift;
    my $sessionsdata = qq();
    my $DEBUG = NSMF::DEBUG;

    if (open (FILE, $sfile)) {
        if ($DEBUG) {
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
      print "Sessions data:\n$sessionsdata\n" if $DEBUG;
      return $sessionsdata;
      }
      
}


=head2 _dir_watch

 Looks for new session data files in $cxtdir regulary.
 If a new session files i found, it will try to send its data to the server.

=cut
1;
