package NSMF::Action;

use strict;
use v5.10;

use POE;
use POE::Component::DirWatch;
use NSMF::Util;
use Data::Dumper;

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
        interval => 1,
    );
}

sub authenticate {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    my $nodename = $heap->{nodename};
    $heap->{stage} = 'auth';
    $heap->{server}->put("AUTH $nodename NETGROUP NSMF/1.0");
    print_status "AUTH sent";
}

sub identify {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    my $nodename = $heap->{nodename};
    $heap->{stage} = 'id';
    $heap->{server}->put("ID 1234 $nodename NSMF/1.0");
}

sub ping {
    my ($kernel, $heap, $response) = @_[KERNEL, HEAP, ARG0];
    my $nodename = $heap->{nodename};
    return unless $heap->{stage} eq 'connected';
    $heap->{server}->put("PING 123123 NSMF/1.0");
}

sub got_ok {
    my ($kernel, $arg) = @_[KERNEL, ARG0];
    say "Got OK!: $arg";
}

1;
