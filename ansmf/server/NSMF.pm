package NSMF;

use v5.10;
use strict;
use Carp;
use NSMF::ConfigMngr;

NSMF::ConfigMngr->instance;

my $server_config = 'server.yaml';

unless (-f -r $server_config) {
    croak 'Server Configuration File Not Found';
}

NSMF::ConfigMngr::instance->load($server_config);

our $DEBUG = $NSMF::ConfigMngr::debug;

1;
