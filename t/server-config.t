#!/usr/bin/perl -w

use Data::Dumper;
use lib '../lib';
use strict;
use 5.010;
use Test::More 'no_plan';

my $config_module = "NSMF::Server::ConfigMngr";
use_ok($config_module);

my @subs = qw( 
    load name node_host node_port 
    client_host client_port modules
    database protocol logging instance
);

can_ok($config_module, @subs);
my $config = $config_module->instance;
$config->load('../etc/server.yaml');

isa_ok($config, $config_module);

ok( $config->name eq 'NSMF Server' );

is_deeply( $config->modules,  ['cxtracker', 'barnyard2'], 'Modules compare');
is_deeply( $config->database, { 
    pass => 'passw0rd.', 
    user => 'nsmf', 
    name => 'nsmf',
    type => 'mysql',
    port => '3306',
    host => 'localhost',
}, 'Database data Check');

ok( $config->node_host eq 'localhost' && $config->node_port ~~ 10101, 
    'Server and Port Node Check');

ok( $config->client_host eq 'localhost' && $config->client_port ~~ 10201,
    'Server and Port Client Check');

ok( $config->protocol ~~ 'json', 'Protocol Check');
