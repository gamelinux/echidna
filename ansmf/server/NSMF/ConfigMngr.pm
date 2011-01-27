package NSMF::ConfigMngr;
    
use v5.10;
use strict;

use Carp qw(croak);
use YAML::Tiny;

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
    $instance = $self;

    return $instance;
}

1;
