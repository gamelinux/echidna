package NSMF::Core;

use strict;
use v5.10;

# NSMF Imports
use NSMF;
use NSMF::Common::Util;
use NSMF::ProtoFactory;

# POE Imports
use POE;
use POE::Filter::Stream;
use POE::Component::Client::TCP;

# Misc
use Carp qw(croak);
use Data::Dumper;

my $self;
my $proto = NSMF::ProtoFactory->create("HTTP");

sub init {

    ($self) = @_;
    my ($server, $port) = ($self->server, $self->port);

    print_error "Host or Port not defined." unless defined_args($server, $port);

    POE::Component::Client::TCP->new(
        RemoteAddress => $server,
        RemotePort    => $port,
        Filter        => "POE::Filter::Stream",
        Connected => sub {
            print_status "[+] Connected to $server:$port ...";

            $_[HEAP]->{nodename} = $self->nodename;
            $_[HEAP]->{netgroup} = $self->netgroup;
            $_[HEAP]->{secret}   = $self->secret;
            $_[HEAP]->{agent}    = $self->agent;

            $_[KERNEL]->yield('authenticate');
        },
        ConnectError => sub {
            print_status "Could not connect to $server:$port ...";
        },
        ServerInput => sub {
            my ($kernel, $response) = @_[KERNEL, ARG0];
            
            $kernel->yield(dispatcher => $response);
        },
        ServerError => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            print_status "Lost connection to server...";
            print_status "Going Down";
            exit;
        },
        ObjectStates => [
            $proto => $proto->states,
        ],
        InlineStates => {
            run => \&run,
        }
    );
}

sub run {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    say "-> Calling run";
    $self->run($kernel, $heap);
}

1;
