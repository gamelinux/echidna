package NSMF::Auth;

use strict;
use v5.10;
use NSMF;
use NSMF::Util;
our $VERSION = '0.1';

sub send_auth {	 	                  

    my ($conn, $config) = @_;

    my $ID         = $config->{id};
    my $NODENAME   = $config->{nodename};
    my $SECRET 	   = $config->{secret};
    my $NETGROUP   = $config->{netgroup};
    my $NSMFSERVER = $config->{server};

    return 0 unless defined_args($ID, $NODENAME, $SECRET, $NETGROUP, $NSMFSERVER);

    my $line = qq();

    if (defined $conn) {
        my $HEADER = "AUTH $NODENAME NSMF/1.0";

        print $conn "$HEADER\0";
        print_status "Sent HEADER: '$HEADER'." if NSMF::DEBUG;

        $conn->flush();
        sysread($conn, $line, 8192, length $line);
        chomp $line;

        $line =~ s/\r//;

        if ( $line =~ NSMF::ACCEPTED ) {
            print_status "Server $NSMFSERVER sent response: '$line'." if NSMF::DEBUG;

            my $ID = "$ID $SECRET $NODENAME $NETGROUP";

            print $conn "$ID\0";
            print_status "Sent ID: '$ID'." if NSMF::DEBUG;
            $conn->flush();

            $line = qq();
            sysread($conn, $line, 8192, length $line);
            chomp $line;

            $line =~ s/\r//;

            if ( $line =~ NSMF::ACCEPTED ) {

                $line = qq();
                sysread($conn, $line, 8192, length $line);
                chomp $line;

                return $line; #OK
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
