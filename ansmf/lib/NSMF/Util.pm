package NSMF::Util;

use strict;
use v5.10;
use base qw(Exporter);
use DateTime;
use Data::Dumper;
use Carp qw(croak);
our @EXPORT = qw(print_status print_error defined_args debug log);
our $VERSION = '0.1';

sub verify_node {
    my ($self) = @_;
    return unless ref($self) ~~ /NSMF::Node/;
}

sub print_status {
    my ($message) = @_;
    say "[*] $message";
}

sub print_error {
    my ($message) = @_;
    say "[!!] $message";
    exit;
}

sub defined_args {
    my @args = @_;

    return unless @args;

    for (@args) {
        when(undef) {
            return;
        }
    }

    return 1;
}

sub debug {
    my @args = @_;

    $Data::Dumper::Terse = 1;

    foreach (@args) {
        say Dumper $_;
    }

}

sub log {
    my ($message, $logfile) = @_;
    my $dt = DateTime->now;

    $Data::Dumper::Terse = 1;
    
    $logfile //= 'debug.log';
    open(my $fh, ">>", $logfile) or die $!;
    say $fh $dt->datetime;
    say $fh Dumper $message;
    close $fh;
}

1;
