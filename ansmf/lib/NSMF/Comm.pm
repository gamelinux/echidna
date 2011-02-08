package NSMF::Comm;

use strict;
use NSMF::Util;
use POE;
use POE::Component::Client::TCP;
use POE::Filter::Stream;
use Carp qw(croak);
use v5.10;
use Data::Dumper;

sub connect {

    my ($self) = @_;
    my ($server, $port) = ($self->server, $self->port);

    croak "Host or Port not defined." unless defined_args($server, $port);

    POE::Component::Client::TCP->new(
        RemoteAddress => $server,
        RemotePort    => $port,
        Filter        => "POE::Filter::Stream",
        Connected => sub {
            print_status "[+] $server:$port ...";
            $_[KERNEL]->yield('got_ack');

        },
        ConnectError => sub {
            print_status "Could not connect to $server:$port ...";
        },
        ServerInput => sub {
            my ($kernel, $heap, $input) = @_[KERNEL, HEAP, ARG0];
            if ($input ~~ /FOUND/) {
        #        $kernel->yield('got_response' => $input);
            }
            print_status "Got input from $server:$port ...";
            $kernel->delay(shutdown => 60);
        },
        ObjectStates => [
            $self => { got_ack => 'ack',
                        got_response => 'rsp',
            },
        ],
        InlineStates => {  
            send_data => sub {
                $_[HEAP]->{server}->put("AUTH SNORT DMZ NSMF/1.0");
            }

        },
    );

    $poe_kernel->run();
    print_status "Connection Finalized.";
}

1;
