package NSMF::Comm;

use strict;
use NSMF::Util;
use POE;
use POE::Component::Client::TCP;
use POE::Filter::Stream;
use Carp qw(croak);
use v5.10;


sub connect {

    my ($server, $port) = @_;

    croak "Host or Port not defined." unless defined_args($server, $port);

    POE::Component::Client::TCP->new(
        RemoteAddress => $server,
        RemotePort    => $port,
        Filter        => "POE::Filter::Stream",

        Connected => sub {
            print_status "[+] $server:$port ...\n";

            $_[HEAP]->{banner_buffer} = [];
            $_[KERNEL]->delay(send_enter => 5);
        },

        ConnectError => sub {
            print_status "Could not connect to $server:$port ...";
        },

        ServerInput => sub {
            my ($kernel, $heap, $input) = @_[KERNEL, HEAP, ARG0];

            print_status "Got input from $server:$port ...";

            push @{$heap->{banner_buffer}}, $input;
            $kernel->delay(send_enter    => undef);
            $kernel->delay(input_timeout => 1);
        },

        InlineStates => {  
    	  
            send_enter => sub {
                print_status "Sending enter on $server:$port ...";

                $_[HEAP]->{server}->put("");    # sends enter
                $_[KERNEL]->delay(input_timeout => 5);
            },

            input_timeout => sub {
                my ($kernel, $heap) = @_[KERNEL, HEAP];
                print_status "got input timeout from $server:$port ...";
                print_status ",----- Banner from $server:$port";
                foreach (@{$heap->{banner_buffer}}) {
                   print "| $_";
                }

                print_status "`-----";
                $kernel->yield("shutdown");
            },
        },
    );

    $poe_kernel->run();
    print_status "Connection Finalized.";
}

1;
