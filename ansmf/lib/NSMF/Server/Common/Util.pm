package NSMF::Server::Common::Util;

use strict;
use v5.10;
use base qw(Exporter);
use Data::Dumper;
use Carp qw(croak);
our @EXPORT = qw(
    puts
    print_status 
    print_error 
    trim
    defined_args 
    parse_request
    debug 
    log
);
our $VERSION = '0.1';

sub puts {

    return unless $NSMF::Server::DEBUG;
    say for @_;
}

sub parse_request {
    my ($type, $input) = @_;

    if (ref $type) {
        my %hash = %$type;
        $type = keys %hash;
        $input = $hash{$type};
    }
    my @types = qw(
        auth id get post
    );
    #$type = undef;
    return unless grep $type, @types;
    return unless defined $input;

    my @request = split '\s+', $input;
    given($type) {
        when(/auth/i) { 
            return bless { 
                method   => $request[0],
                agent    => $request[1],
                key       => $request[2],
                tail     => $request[3],
            }, 'AUTH';
        }
        when(/id/i) {
            return bless {
                method => $request[0] // undef,
                node   => $request[1] // undef,
            }, 'ID';
        }
        when(/get/i) {
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                query  => $request[4] // undef,
            }, 'GET';
        }
        when(/post/i) {

            my @data;
            push @data, $request[$_] for (4..$#request);
            return bless {
                method => $request[0] // undef,
                type   => $request[1] // undef,
                job_id => $request[2] // undef,
                tail   => $request[3] // undef,
                data   => \@data // undef,
            }, 'POST';
        }
    }
}

sub trim {
    my ($msg) = @_;
    $msg =~ s/^\s+//g;
    $msg =~ s/\s+$//g;
    return $msg;
}

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

    for my $arg (@args) {
        return if ( ! defined($arg) );
    }

    return 1;
}

sub check_config {  
    my $config = shift;
    my @KEYS = qw(id nodename netgroup secret server port);

    foreach my $key (@KEYS) {
        not_defined("$key") unless grep $_ eq $key, @KEYS and defined $config->{$key};
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
