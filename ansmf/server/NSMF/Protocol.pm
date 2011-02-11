package NSMF::Protocol;

use v5.10;
use strict;

use POE;
use NSMF;
use NSMF::Credential;
use NSMF::ConfigMngr;
use Data::Dumper;
use Carp qw(croak);
use base qw(Exporter);
our $VERSION = '0.1';
our @EXPORT = qw( got_auth got_ping send_ack send_err authenticate got_post);

my $config = NSMF::ConfigMngr->instance;
my $modules = $config->{modules} // [];
map { $_ = uc($_) } @$modules;

sub got_auth {
    my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
    say "  - Got AUTH: " . $input if $NSMF::DEBUG;

    my @request = split '\s+', $input;
    my $module = $request[1];
    say $module;
    if (uc($module) ~~ @$modules) {
        say 'Found';
        $heap->{client}->put("NSMF/1.0 MODULE " . uc($module) . " FOUND\r\n");
        $heap->{$module} = {};
    } else {
        say 'Not Found';
        $heap->{client}->put("NSMF/1.0 MODULE NOT FOUND\r\n");
    }
}

sub authenticate {
    my ($kernel, $session, $heap, $request) = @_[KERNEL, SESSION, HEAP, ARG0];

    my @data = split '\s+', $request;
    my $key = $data[1];
    my $module = $data[2];
    my $credential;

    eval {
        $credential = NSMF::Credential->search({ nodename => lc($module) })->next;
    };
    
    if($@) {
        croak '[!!] There is a problem with the Database configuration. Check Credentials.';
    }

    return unless (ref $heap->{$module});
    if ($heap->{$module}->{session_id}) {
        say "$module is already authenticated" if $NSMF::DEBUG;
        return;
    }
    
    if ($key ~~ $credential->password) {
        say " [+] ", uc($module)," authenticated!" if $NSMF::DEBUG;
        $heap->{$module}->{session_id} = 1;
        $heap->{client}->put("NSMF/1.0 202 Accepted\r\n");
    } else {
        $heap->{client}->put("NSMF/1.0 401 Unauthorized\r\n");
    }

}

sub got_ping {
    my ($heap, $input) = @_[HEAP, ARG0];
    say "  - Got PING" if $NSMF::DEBUG;
    my $time = localtime;
    $heap->{client}->put("NSMF/1.0 PONG $time\r\n")
}

sub send_ack {
   say 'ACL'; 
}

sub send_err {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $client = $heap->{client};
    say "Bad Request" if $NSMF::DEBUG;
    $client->put("NSMF/1.0 400 Bad Request\r\n");
}

sub got_post {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];
    my @data = split '\n', $request;
    say Dumper @data;
}   

1;
