#!/usr/bin/perl -w

use strict;
use 5.010;

use File::Spec;
use FindBin qw($Bin);
use lib File::Spec->catdir($Bin, "..", "lib");

use Data::Dumper;

use AnyEvent;
use AnyEvent::DBI;
use Test::More 'no_plan';

use_ok('AnyEvent');
use_ok('NSMF::Database::Pool::MySQL');

my $pool = NSMF::Database::Pool::MySQL->new({ 
        database => 'nsmf',
        user     => 'nsmf',
        password => 'passw0rd.',
        size     => 5,
});

my $dbi;

for (1..5) {
    $dbi = $pool->fetch;
    ok('AnyEvent::DBI' ~~ ref $dbi, 'Should be an instance of AnyEvent::DBI');
    can_ok( $dbi, 'exec');
}
ok(5 == $pool->total, 'Should have 5 Connections on Pool');

for (1..5) {
    my $cv = AE::cv;
    $dbi->exec("SELECT SLEEP(0.1)", sub {
        $cv->send("Done");
    });

    ok("Done" eq $cv->recv, "Should return 'Done' after async query");
}
