package NSMF::AuthMngr;

use strict;
use v5.10;
use NSMF::Model::Agent;
use Carp;

sub authenticate {
    my ($self, $agent_name, $key) = @_;
    
    my $agent = NSMF::Model::Agent->search({
        agent_name => $agent_name,
    })->next;

    if ($agent and ref $agent eq 'NSMF::Model::Agent') {

        if ($agent->agent_password eq $key) {
            return 1;
        }
        else { 
            croak { status => 'error', message => 'Incorrect Password' };
        }
    } 
    else {
        croak {status => 'error', message => 'Agent Not Found'};
    }
}


1;
