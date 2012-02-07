#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use lib '../lib';
use Test::More 'no_plan';
use Test::Mojo;
use NSMF::Web::Server;
my $t = Test::Mojo->new(NSMF::Web::Server->new);


my @resources = qw(
    session
    event
);
for my $resource (@resources) {

    my $uri = '/' .$resource;
    # GET /<RESOURCE> 
    $t->get_ok($uri)->status_is(200)
        ->content_type_is('application/json');

    # POST /<RESOURCE>
    
    # PUT /<RESOURCE>

    # DELETE /<RESOURCE>
}
