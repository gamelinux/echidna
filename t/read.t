#!/usr/bin/perl 

use strict;
use 5.010;

use lib '../lib';
use Data::Dumper;
use Test::More 'no_plan';
use AnyEvent;

use_ok 'NSMF::Service::Database';

my $settings = {
   type => 'mysql',
   user => 'echidna',
   name => 'echidna',
   pass => 'passw0rd.',
   pool_size => 10,
   #debug => 1,
};

my $db = NSMF::Service::Database->new(mysql => $settings);

my $cv = AE::cv;
$db->call(session => 'longest_session', undef, sub {
    my ($rs, $err) = @_;

    say "Fail" if $err;

    say Dumper $rs;
    $cv->send;
});
$cv->recv;
