package NSMF::Auth;

use strict;

my $DEBUG = 1;

sub send_auth {	 	                  
   
    my $conn 	   = shift;
    my ($config)   = @_;
    my $ID 	   = $config->{ID} if defined $config->{ID};
    my $NODENAME   = $config->{NODENAME} if defined $config->{NODENAME};
    my $SECRET 	   = $config->{SECRET} if defined $config->{SECRET};
    my $NETGROUP   = $config->{NETGROUP} if defined $config->{NETGROUP};
    my $NSMFSERVER = $config->{NSMFSERVER} if defined $config->{SERVER};

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
