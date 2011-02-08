package NSMF::ConfigMngr;
    
use v5.10;
use strict;

use Carp qw(croak);
use YAML::Tiny;

our $debug;
my $instance;
my ($server, $settings);

sub instance {
    my ($class) = @_;
    unless (defined $instance) {
        $instance = bless {
            name     => 'NSMFServer',
            server   => '127.0.0.1',
            port     => 10101,
            settings => {},
            modules    => [],
        }, $class;
        return $instance;
    }
    return $instance;
}

sub load {
    my ($self, $file) = @_;

    return unless ref($self) eq 'NSMF::ConfigMngr';

    my $yaml = YAML::Tiny->read($file);
    croak 'Could not parse configuration file.' unless $yaml;

    $self->{server}   = $yaml->[0]->{server}   // '0.0.0.0';
    $self->{port}     = $yaml->[0]->{port}     // 0;
    $self->{settings} = $yaml->[0]->{settings} // {};
    $self->{modules}  = $yaml->[0]->{modules}  // [];
    $debug = $yaml->[0]->{settings}->{debug}   // 0;
    $instance = $self;

    return $instance;
}

sub name {
    return $instance->{name} // 'NSMFServer';
}

sub address {
    return $instance->{server} // croak '[!] No server defined.';
}

sub port {
    return $instance->{port} // croak '[!] No port defined.';
}

1;
