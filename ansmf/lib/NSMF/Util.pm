package NSMF::Util;

use strict;
use v5.10;
use base qw(Exporter);
use Data::Dumper;
use Carp qw(croak);
our @EXPORT = qw(
    trim
    defined_args 
);

our $VERSION = '0.1';

sub trim {
    my ($msg) = @_;
    $msg =~ s/^\s+//g;
    $msg =~ s/\s+$//g;
    return $msg;
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

#
# DEPRECATED
#
sub verify_node {
    my ($self) = @_;
    return unless ref($self) ~~ /NSMF::Node/;
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
