package NSMF::Node::Core;

use warnings;
use strict;
use v5.10;

# NSMF Imports
use NSMF::Node;
use NSMF::Util;
use NSMF::Common::Logger;
use NSMF::Node::ProtoMngr;

# POE Imports
use POE;
use POE::Filter::Stream;
use POE::Component::Client::TCP;

# Misc
use Carp qw(croak);
use Data::Dumper;

my $self;
my $proto;
my $logger;

eval {
  $proto = NSMF::Node::ProtoMngr->create("JSON");
  $logger = NSMF::Common::Logger->new();
};

if ( $@ )
{
  $logger->error(Dumper($@));
}

sub init {

    ($self) = @_;
    my ($server, $port) = ($self->server, $self->port);

    $logger->error('Host or Port not defined.') if ( ! defined_args($server, $port) );

    POE::Component::Client::TCP->new(
        RemoteAddress => $server,
        RemotePort    => $port,
        Filter        => "POE::Filter::Stream",
        Connected => sub {
            $logger->info("[+] Connected to $server:$port ...");

            $_[HEAP]->{nodename} = $self->nodename;
            $_[HEAP]->{netgroup} = $self->netgroup;
            $_[HEAP]->{secret}   = $self->secret;
            $_[HEAP]->{agent}    = $self->agent;

            $_[KERNEL]->yield('authenticate');
        },
        ConnectError => sub {
            $logger->info("Could not connect to $server:$port ...");
        },
        ServerInput => sub {
            my ($kernel, $response) = @_[KERNEL, ARG0];
            
            $kernel->yield(dispatcher => $response);
        },
        ServerError => sub {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            $logger->info("Lost connection to server...");
            $logger->info("Going Down");
            exit;
        },
        ObjectStates => [
            $proto => $proto->states(),
        ],
        InlineStates => {
            run => \&run,
        }
    );
}

sub run {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    $logger->debug('-> Calling run');
    $self->run($kernel, $heap);
}

1;
