package NSMF::Auth;

use strict;
use NSMF;
use NSMF::Util;
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
        print_status "Sent HEADER: '$HEADER'." if $DEBUG;
        $conn->flush();
        sysread($conn, $line, 8192, length $line);
        chomp $line;
        $line =~ s/\r//;

        if ( $line =~ /$NSMF::Constants::ACCEPTED/ ) {
            print_status "Server $NSMFSERVER sent response: '$line'." if $DEBUG;
            my $ID = "$ID $SECRET $NODENAME $NETGROUP";
            print $conn "$ID\0";
            print_status "Sent ID: '$ID'." if $DEBUG;
            $conn->flush();
            $line = qq();
            sysread($conn, $line, 8192, length $line);
            chomp $line;
            $line =~ s/\r//;
            if ( $line =~ /$NSMF::Constants::ACCEPTED/ ) {
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
