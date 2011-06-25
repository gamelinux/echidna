package NSMF::Util;

use strict;
use v5.10;
use base qw(Exporter);
use Data::Dumper;
use Carp qw(croak);
our @EXPORT = qw(
    print_status 
    print_error 
    trim
    defined_args 
    parse_request
);

our $VERSION = '0.1';

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

sub check_config {  
    my $config = shift;
    my @KEYS = qw(id nodename netgroup secret server port);

    foreach my $key (@KEYS) {
        not_defined("$key") unless grep $_ eq $key, @KEYS and defined $config->{$key};
    }

    return 1;
}



1;
