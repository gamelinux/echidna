package NSMF::Util;

use strict;
use v5.10;
use base qw(Exporter);
use Data::Dumper;
use Carp qw(croak);
our @EXPORT = qw(
    parse_request
    print_status 
    print_error 
    defined_args 
    debug 
    log
);
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

sub parse_request {
    my ($type, $input) = @_;

    if (ref $type) {
        my %hash = %$type;
        $type = keys %hash;
        $input = $hash{$type};
    }
    my @types = (
        'auth',
        'get',
        'post',
    );

    return unless grep $type, @types;
    return unless defined $input;

    my @request = split '\s+', $input;
    given($type) {
        when(/AUTH/i) { 
            return bless { 
                method   => $request[0],
                nodename => $request[1],
                netgroup => $request[2],
                tail     => $request[3],
            }, 'AUTH';
        }
        when(/GET/i) {
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                query  => $request[4] // undef,
            }, 'POST';
        }
        when(/POST/i) {
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                data   => $request[4] // undef,
            }, 'POST';
        }
    }
}

1;
