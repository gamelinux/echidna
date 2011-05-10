package NSMF::AuthMngr;

use strict;
use v5.10;
use NSMF::Agent;
use Carp;

sub authenticate {
    my ($self, $agent_name, $key) = @_;
    
    my $agent = NSMF::Agent->search({
        agent_name => $agent_name,
    })->next;

    if ($agent and ref $agent eq 'NSMF::Agent') {
        if ($agent->agent_password eq $key) {
            return 1;
        }
        else { 
            croak 'Incorret Password';
        }
    } 
    else {
        croak 'Agent Not Found';
    }
}


1;
