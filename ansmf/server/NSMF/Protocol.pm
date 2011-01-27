package NSMF::Protocol;

use v5.10;
use strict;

use POE;
use NSMF::Credential;
use base qw(Exporter);
our $VERSION = '0.1';

our @EXPORT = qw( got_auth got_ping send_ack send_err authenticate);

my @modules = qw( cxtracker snort);

sub got_auth {
    my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
    say "  - Got AUTH: " . $input;

    my @request = split '\s+', $input;
    my $module = $request[1];

    if ($module ~~ @modules) {
        $heap->{client}->put("NSMF/1.0 MODULE " . uc($module) . " FOUND\r\n");
        $heap->{$module} = {};
    } else {
        $heap->{client}->put("NSMF/1.0 MODULE NOT FOUND\r\n");
    }
}

sub authenticate {
    my ($kernel, $session, $heap, $request) = @_[KERNEL, SESSION, HEAP, ARG0];

    my @data = split '\s+', $request;
    my $key = $data[1];
    my $module = $data[2];
    my $credential = NSMF::Credential->search({nodename => $module})->next;
    
    return unless (ref $heap->{$module});
    if ($heap->{$module}->{session_id}) {
        say "$module is already authenticated";
        return;
    }
    
    if ($key == $credential->password) {
        say " [+] ", uc($module)," authenticated!";
        $heap->{$module}->{session_id} = 1;
        $heap->{client}->put("NSMF/1.0 202 Accepted\r\n");
    } else {
        $heap->{client}->put("NSMF/1.0 401 Unauthorized\r\n");
    }

}

sub got_ping {
    my ($heap, $input) = @_[HEAP, ARG0];
    say "  - Got PING";
    my $time = localtime;
    $heap->{client}->put("NSMF/1.0 PONG $time\r\n")
}

sub send_ack {
   say 'ACL'; 
}

sub send_err {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $client = $heap->{client};
    say "Bad Request";
    $client->put("NSMF/1.0 400 Bad Request\r\n");
}



1;
