package NSMF::Node::CXTRACKER;

use strict;
use v5.10;
use base qw(NSMF::Node);
use NSMF::Util;
our $VERSION = '0.1';

sub run {
    my ($self) = @_;
     
    return unless  $self->session;
    print_status("Running cxtracker processing..");
    _dir_watch();
}

=head2 _dir_watch

 Looks for new session data files in $CXTDIR regulary.
 If a new session files i found, it will try to send its data to the server.

=cut

sub _dir_watch {
    my ($self) = @_;
    my $SS = $self->{__handlers}->{_net};

    while (1) {
        if (defined $SS) {
            my @FILES;
            # Open the directory
            if( opendir( DIR, $CXTDIR ) ) {
                # Find session files in dir (stats.eth0.1229062136)
                while( my $FILE = readdir( DIR ) ) {
                    next if( ( "." eq $FILE ) || ( ".." eq $FILE ) );
                    next unless ($FILE =~ /^stats\..*\.\d{10}$/);
                    push( @FILES, $FILE ) if( -f "$CXTDIR/$FILE" );
                }
                closedir( DIR );
            }
            # If we find any files, proccess...
            foreach my $FILE ( @FILES ) {
                my $starttime=time();
                print "[*] Found file: $CXTDIR/$FILE\n" if ($DEBUG);
                my $SESSIONSDATA = _get_sessions("$CXTDIR/$FILE");
                my $endtime=time();
                my $processtime=$endtime-$starttime;
                print "[*] File $CXTDIR/$FILE processed in $processtime seconds\n" if ($DEBUG);
                $starttime=$endtime;
                my $result = send_data_to_server($DEBUG,$SESSIONSDATA,$SS);
                if ($result >= 1) {
                    print "[E] Error while sending sessiondata to server: $CXTDIR/$FILE -> $NSMFSERVER:$NSMFPORT\n";
                    print "[*] Skipping deletion of file: $CXTDIR/$FILE\n";
                }
                $endtime=time();
                $processtime=$endtime-$starttime;
                if ($result == 0) {
                    print "[*] Sessiondata sent in $processtime seconds\n" if ($DEBUG);
                    print "[W] Deleting file: $CXTDIR/$FILE\n";
                    unlink("$CXTDIR/$FILE") if $result == 0;
                }
                # Dont pool files to often, or to seldom...
                #sleep 1; # FIXME delete when testing is done, add INET_ATON6 first :)
            }
        } else {
            print "[E] Could not connect/auth to server: $NSMFSERVER:$NSMFPORT, trying again in 15sec...\n";
            sleep 15;
            $SS->close() if defined $SS;
            return;
        }
    }
}

=head2 get_sessions

 This sub extracts the session data from a session data file.
 Takes $file as input parameter.

=cut

sub get_sessions {
    my $SFILE = shift;
    my $sessionsdata = q();

    if (open (FILE, $SFILE)) {
        my $filelen=`wc -l $SFILE |awk '{print \$1'}`;
        my $filesize=`ls -lh $SFILE |awk '{print \$5}'`;
        chomp $filelen;
        chomp $filesize;
        print "[*] File:$SFILE, Lines:$filelen, Size:$filesize\n" if $DEBUG;
        # Verify the data in the session files
        LINE:
        while (my $line = readline FILE) {
            chomp $line;
            $line =~ /^\d{19}/;
            unless($line) {
                warn "[*] Error: Not valid session start format in: '$SFILE'";
                next LINE;
            }
            my @elements = split/\|/,$line;
            unless(@elements == 15) {
                warn "[*] Error: Not valid Nr. of session args format in: '$SFILE'";
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
      print "Sessionsdata:\n$sessionsdata\n" if $DEBUG;
      return $sessionsdata;
      }
}


1;
