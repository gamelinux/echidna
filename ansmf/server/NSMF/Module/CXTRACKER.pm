package NSMF::Module::CXTRACKER;

use strict;
use v5.10;

use base qw(NSMF::Module);
use Data::Dumper;

use NSMF::Driver;

__PACKAGE__->install_properties({
    columns => [
	    'id', 
	    'session_id', 
	    'start_time',
	    'end_time',
	    'duration',
	    'ip_proto',
	    'ip_version',
        'src_ip',
        'src_port',
        'dst_ip',
        'dst_port',
        'src_pkts',
        'src_bytes',
        'dst_pkts',
        'dst_bytes',
        'src_flags',
        'dst_flags',
    ],
    datasource => 'nsmf_cxtracker',
    primary_key => [ 'id', 'session_id'],
    driver => NSMF::Driver->driver,
});


sub hello {
    say "Hello World from CXTRACKER Module!!";
}

sub validate {
    my ($self, $session) = @_;

    $session =~ /^\d{19}/;

    unless($session) {
        warn "[*] Error: Not valid session start format in"
    }

    my @elements = split /\|/, $session;
    unless(@elements == 15) {
        warn "[*] Error: Not valid Nr. of session args format";
        return;
    }

    say "   -> Valid Session!";

    1;
 
}

sub save {
    my ($self, $session) = @_;

    # validation
    #say " Session Id must be integer " unless $session =~ /\d+/;
    
    my @tokens = split /\|/, $session;

    $self->session_id( $tokens[0] );
    $self->start_time( $tokens[1] );
    $self->end_time( $tokens[2] );
    $self->duration( $tokens[3] );
    $self->ip_proto( $tokens[4] );
    $self->src_ip( $tokens[5] );
    $self->src_port( $tokens[6] );
    $self->dst_ip( $tokens[7] );
    $self->dst_port( $tokens[8] );
    $self->src_pkts( $tokens[9] );
    $self->src_bytes( $tokens[10] );
    $self->dst_pkts( $tokens[11] );
    $self->dst_bytes( $tokens[12] );
    $self->src_flags( $tokens[13] );
    $self->dst_flags( $tokens[14] );
    $self->ip_version( 4 );

    # if everything is ok
    $self->SUPER::save or warn $self->errstr;
        
}



1;
