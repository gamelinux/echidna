package NSMF::Server::ConfigMngr;
    
use v5.10;
use strict;

use Carp;
use YAML::Tiny;

our $debug;
my $instance;
my ($server, $settings);

sub instance {
    if ( ! defined($instance) ) {
        $instance = bless {
            name     => 'NSMFServer',
            server   => '127.0.0.1',
            port     => 10101,
            settings => {},
            modules  => [],
        }, __PACKAGE__;
    }

    return $instance;
}

sub load {
    my ($self, $file) = @_;

    return if ( ref($self) ne __PACKAGE__ );

    __PACKAGE__->instance();

    my $yaml = YAML::Tiny->read($file);
    croak 'Could not parse configuration file.' unless $yaml;

    $self->{server}   = $yaml->[0]->{server}   // '0.0.0.0';
    $self->{port}     = $yaml->[0]->{port}     // 0;
    $self->{settings} = $yaml->[0]->{settings} // {};
    $self->{modules}  = $yaml->[0]->{modules}  // [];
    map { $_ = lc $_ } @{ $self->{modules} };
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

sub modules {
    my $self = shift;
    return unless ref $self eq __PACKAGE__;

    return $instance->{modules};
}

sub protocol {
    my $self = shift;
    return unless ref $self eq __PACKAGE__;

    return $instance->{settings}->{protocol};
}

sub debug_on {
    my $self = shift;
    return unless ref $self eq __PACKAGE__;

    return $instance->{settings}->{debug};
}

1;
