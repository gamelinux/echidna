package NSMF;

use v5.10;
use strict;

use NSMF::ConfigMngr;

NSMF::ConfigMngr->instance;
NSMF::ConfigMngr::instance->load('server.yaml');

our $DEBUG = $NSMF::ConfigMngr::debug;

1;
