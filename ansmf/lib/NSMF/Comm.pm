package NSMF::Comm;

use strict;
use NSMF::Util;
use POE;
use POE::Component::Client::TCP;
use POE::Filter::Stream;
use NSMF;
use Carp qw(croak);
use v5.10;
use Data::Dumper;

my $self;

sub init {

    ($self) = @_;
    my ($server, $port) = ($self->server, $self->port);
    print_status "Connecting";
    croak "Host or Port not defined." unless defined_args($server, $port);

    POE::Component::Client::TCP->new(
        RemoteAddress => $server,
        RemotePort    => $port,
        Filter        => "POE::Filter::Stream",
        Connected => sub {
            print_status "[+] $server:$port ...";

            $_[HEAP]->{nodename} = 'CXTRACKER';
            $_[KERNEL]->yield('auth');
            print_status ">> Authenticating..";

        },
        ConnectError => sub {
            print_status "Could not connect to $server:$port ...";
        },
        ServerInput => sub {
            my ($kernel, $heap, $input) = @_[KERNEL, HEAP, ARG0];
            
            print_status "Got input from $server:$port ...";
            say "[DEBUG] $input";

            $kernel->yield(dispatcher => $input);
#            $kernel->delay(shutdown => 60);
        },
        ObjectStates => [
            $self => { 
                auth   => 'authenticate',
                id     => 'identify',
                ping   => 'ping',
                got_ok => 'got_ok',
            },
        ],
        InlineStates => {
            dispatcher => \&dispatcher,
            loop       => \&loop,
        }
    );

    $poe_kernel->run();
    print_status "Connection Finalized.";
}

sub loop {
    say "alooo";
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    $self->run();
#    $_[HEAP]->{watcher} = $self->watcher('/var/lib/cxtracker', '_process');
    
}

sub dispatcher {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    my $action = '';
    given($request) {
        when(/FOUND/) {
            given($heap->{stage}) {
                when('auth') {
                    $action = 'id';
                } default: {
                    return;
                }
            }
        }
        when(/NSMF\/1.0 202 Accepted/) {
            if ($heap->{stage} eq 'id') {
                $heap->{stage} = 'session';
                say 'We are wired in baby!';
                $kernel->yield('loop');
                return;
            } 
        }
        default: {
            $action = 'ping';
        }
    }
    $kernel->yield($action) if $action;
}

1;
