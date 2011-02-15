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
#    croak "Host or Port not defined." unless defined_args($server, $port);

    POE::Component::Client::TCP->new(
        RemoteAddress => $server,
        RemotePort    => $port,
        Filter        => "POE::Filter::Stream",
        Connected => sub {
            print_status "[+] $server:$port ...";

            $_[HEAP]->{nodename} = $self->nodename;
            $_[HEAP]->{secret}   = $self->secret;

            $_[KERNEL]->yield('auth');
            print_status "Authenticating..";

        },
        ConnectError => sub {
            print_status "Could not connect to $server:$port ...";
        },
        ServerInput => sub {
            my ($kernel, $input) = @_[KERNEL, ARG0];
            
            $kernel->yield(dispatcher => $input);
            $kernel->delay(ping => 5);
        },
        ObjectStates => [
            $self => { 
                auth     => 'authenticate',
                ident    => 'identify',
                ping     => 'send_ping',
                pong     => 'send_pong',
                got_pong => 'got_pong',
                got_ok   => 'got_ok',
                is_alive => 'is_alive',
            },
        ],
        InlineStates => {
            dispatcher => \&dispatcher,
            node       => \&run,
        }
    );

    POE::Kernel->run();
}

sub run {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    $self->run();
}

sub dispatcher {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    my $action = '';
    given($request) {
        when(/FOUND/) {
            given($heap->{stage}) {
                when('REQ') {
                    $action = 'ident';
                } default: {
                    return;
                }
            }
        }
        when(/NSMF\/1.0 202 Accepted/) {
            if ($heap->{stage} eq 'SYN') {
                $heap->{stage} = 'EST';
                say 'We are wired in baby!';
                $kernel->yield('node');
                return;
            } 
        }
        when(/PONG/) {
           $action = 'got_pong'; 
        }
    }
    $kernel->yield($action) if $action;
}

1;
