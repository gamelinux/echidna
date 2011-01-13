package NSMF::Auth;

use strict;
use Data::Dumper;
use v5.10;

my $DEBUG = 1;

sub send_auth {	 	                  
   
    my ($conn, $config) = @_;

    my $ID 	       ||= $config->{id};
    my $NODENAME   ||= $config->{nodename};
    my $SECRET 	   ||= $config->{secret};
    my $NETGROUP   ||= $config->{netgroup};
    my $NSMFSERVER ||= $config->{server};

    my $line = qq();
    if (defined $conn) {
        my $HEADER = "AUTH $NODENAME NSMF/1.0";
        print $conn "$HEADER\0";
        print "[*] Sent HEADER: '$HEADER'.\n" if $DEBUG;
        $conn->flush();
        sysread($conn, $line, 8192, length $line);
        chomp $line;
        $line =~ s/\r//;
        if ( $line =~ /200 OK ACCEPTED/ ) {
            print "[*] Server $NSMFSERVER sent response: '$line'.\n" if $DEBUG;
            my $ID = "$ID $SECRET $NODENAME $NETGROUP";
            print $conn "$ID\0";
            print "[*] Sent ID: '$ID'.\n" if $DEBUG;
            $conn->flush();
            $line = qq();
            sysread($conn, $line, 8192, length $line);
            chomp $line;
            $line =~ s/\r//;
            if ( $line =~ /200 OK ACCEPTED/ ) {
                return 1; #OK
            } else {
                return 0; #ERROR
            }
        } else {
            return 0; #ERROR
        }
    } else {
        return 0; #ERROR
    }

}

1;
