package NSMF;

use strict;
use v5.10;

use File::Spec;
use NSMF::ConfigMngr;
use NSMF::ProtoMngr;
use Module::Pluggable search_path => 'NSMF::Component', sub_name => 'modules';
use Module::Pluggable search_path => 'NSMF::Worker', sub_name => 'workers';
use Module::Pluggable search_path => 'NSMF::Proto', sub_name => 'protocols';
use Data::Dumper;

our $DEBUG; 
my $instance;
sub new {  
    unless ($instance) {

        my $config_path = File::Spec->catfile('etc', 'server.yaml');

        unless (-f -r $config_path) {
            die 'Server Configuration File Not Found';
        }

        my $config = NSMF::ConfigMngr::instance;
        $config->load($config_path);
        $DEBUG = 1 if $config->debug_on;

        my $proto = NSMF::ProtoMngr->create($config->protocol);

        $instance = bless {
            __config_path => $config_path,
            __config      => $config,
            __proto       => $proto, 
        }, __PACKAGE__;
        
        return $instance;
    }

    return $instance;
}

# get method for config singleton object
sub config {
    my ($self) = @_;

    return unless ref $instance eq __PACKAGE__;
    die 'Configuration not set' unless $instance->{__config};

    return $instance->{__config} // die { status => 'error', message => 'No Configuration File Enabled' }; 
}

# get method for proto singleton object
sub proto {
    my ($self) = @_;

    return unless ref $instance eq __PACKAGE__;

    return $instance->{__proto} // die { status => 'error', message => 'No Protocol Enabled' };
}

1;
