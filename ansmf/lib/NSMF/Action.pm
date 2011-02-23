package NSMF::Action;

use strict;
use v5.10;

use POE::Component::DirWatch;

#  Returns a POE::Component::DirWatch session
sub watcher {
    my ($self, $dir, $handler) = @_;

    return POE::Component::DirWatch->new(
        alias => 'file_seeker',
        directory => $dir,
        filter => sub { 
        	-f $_[0];
        },
        file_callback => sub {
    	    my ($file) = @_;
            $self->$handler($file);    	
        },
        interval => 3,
    );
}


1;
