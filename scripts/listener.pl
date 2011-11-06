#!/usr/bin/perl 

use strict;
use warnings;
use 5.010;

use File::Spec;
use FindBin qw($Bin);
use lib File::Spec->catdir($Bin, "..", "lib");

use Carp;
use Getopt::Long;
use Data::Dumper;
use Digest::SHA qw/sha1_hex/;

use NSMF::Server::ScriptHelper qw(output fail);

my $PATH   = File::Spec->catdir($Bin, "..");
my $logger = NSMF::Server::ScriptHelper->get('logger');

my ($checksum, $port, $host);
GetOptions(
    "checksum=s" => \$checksum,
    "port=i"     => \$port,
    #"host=s"       => \$host,
);

# validate checksum
unless (defined $checksum and $checksum ~~ /[A-F0-9]{40}/i) {
    fail("LISTENER: Invalid Checksum provided on Listener Script");
}

# validate port
unless (defined $port and $port ~~ /\d{1,5}/) {
    fail("LISTENER: Invalid Port provided on Listener Script");
}

# validate host
unless (defined $host and $host ~~ /^(\d){1,3}\.(\d){1,3}\.(\d){1,3}\.(\d){1,3}$/) {
    #$logger->debug(" Invalid Host provided on Listener Script");
    #exit;
}

use IO::Socket::SSL;
my $server = IO::Socket::SSL->new(
    Proto => 'tcp',
    LocalPort => $port,
    Listen => 1,
    LocalAddr => 'localhost',
    SSL_cert_file => File::Spec->catfile($PATH, "certs", "server-cert.pem"),
    SSL_key_file  => File::Spec->catfile($PATH, "certs", "server-key.pem"),
    Timeout => 4,
) or fail("LISTENER: Failed to create server socket");

output("LISTENER: Listening on port " .$server->sockport);

sub _trim {
    my $msg = @_;
    $msg =~ s/^\s+//;
    $msg =~ s/\s+$//;
    $msg;
}

sub create_random_file {
    my $filename;
    my $count = 0;
    while (1) {
        my $temp_file = 'stream_' .$count;
        unless ( -f File::Spec->catfile($PATH, "tmp", $temp_file) ) {
            $filename = $temp_file;
            last;
        }

        $count++;
        next;  
    }
    return File::Spec->catfile($PATH, "tmp", $filename);
}

my $filepath = create_random_file();

my $client; 
while ($client = $server->accept()) {
    $client->autoflush(1);
    
    output("LISTENER: Opening $filepath");
    open my $fh, '>', $filepath or fail("LISTENER: ". $!);
    binmode($fh);

    my $data;
    while ( read($client, $data, 8192) != 0 ) {
        print $fh $data;
    }

    close $fh or fail("LISTENER: Could not close $filepath handle");
    last;
}

if (ref $client) {
    output("LISTENER: Closing filepath $filepath");
    close $client or fail("LISTENER: Failed to close $filepath handle");
} else {
    fail("LISTENER: Listener Socket Timed Out");
}

my $transmitted_ok = sub {
    my $filename = shift;
    open my $fh, '<', $filename or fail("LISTENER: ". $!);
    my $digest = sha1_hex(<$fh>);
    close $fh or fail("LISTENER: ". $!);

    return 1 if $checksum eq $digest;
};

if ($transmitted_ok->($filepath)) {
    output("SUCCESS");
} else {
    output("FAILED");
}


