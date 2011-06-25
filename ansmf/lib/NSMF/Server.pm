package NSMF::Server;

use strict;
use v5.10;

use File::Spec;
use NSMF::Server::ConfigMngr;
use NSMF::Server::ProtoMngr;
use NSMF::Common::Logger;
use Module::Pluggable search_path => 'NSMF::Server::Component', sub_name => 'modules';
use Module::Pluggable search_path => 'NSMF::Server::Worker', sub_name => 'workers';
use Module::Pluggable search_path => 'NSMF::Server::Proto', sub_name => 'protocols';
use Data::Dumper;

our $DEBUG; 
my $instance;

sub new {  
    unless ($instance) {

        my $config_path = File::Spec->catfile('../etc', 'server.yaml');

        unless (-f -r $config_path) {
            die 'Server Configuration File Not Found';
        }

        my $config = NSMF::Server::ConfigMngr::instance;
        $config->load($config_path);

        my $logger = NSMF::Common::Logger->new();
        $logger->verbosity(5) if $config->debug_on;

        my $proto;

        eval {
            $proto = NSMF::Server::ProtoMngr->create($config->protocol);
        };

        if ( ref($@) )
        {
            $logger->fatal(Dumper($@));
        }

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

    return $instance->{__config} // die { status => 'error', message => 'No Configuration File Enabled' }; 
}

# get method for proto singleton object
sub proto {
    my ($self) = @_;

    return unless ref $instance eq __PACKAGE__;

    return $instance->{__proto} // die { status => 'error', message => 'No Protocol Enabled' };
}

1;
