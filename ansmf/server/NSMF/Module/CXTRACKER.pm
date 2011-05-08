package NSMF::Module::CXTRACKER;

use strict;
use v5.10;
use POE;
use POE::Filter::Reference;
use base qw(NSMF::Module);
use Data::Dumper;

sub new {
    my $class = shift;
    return bless {}, $class;
}

my $filter = POE::Filter::Reference->new;
sub run {  
    my ($self) = @_;

    my $output = $filter->put([
        { action => 'message', data => 'Hello From CXTRACKER!', }
    ]);

    print @$output;
}

sub post {
    my ($self) = @_;
    my $filter = POE::Filter::Reference->new;
    my $output = $filter->put([{ method => 'post', data => [1,2,3,4]}]);
    print @$output;
}

sub get {
    my ($self) = @_;
    my $filter = POE::Filter::Reference->new;
    my $output = $filter->put([{ method => 'post', data => [1,2,3,4]}]);
    print @$output;
}

sub hello {
    say "Hello World from CXTRACKER Module!!";
}

1;
