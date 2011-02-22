package NSMF::Proto;

use v5.10;
use strict;

use NSMF;
use NSMF::Util;
use NSMF::ModMngr;
use NSMF::Credential;
use NSMF::ConfigMngr;

use POE;

use Data::Dumper;
our $VERSION = '0.1';

my $instance;
my $config = NSMF::ConfigMngr->instance;
my $modules = $config->{modules} // [];

map { $_ = uc($_) } @$modules;

my $ACCEPTED = 'NSMF/1.0 200 OK ACCEPTED';

sub instance {

    unless ($instance) {
        my ($class) = @_;
        return bless({}, $class);
    }

    return $instance;
}

sub states {
    my ($self) = @_;

    return unless ref($self) eq 'NSMF::Proto';

    return [
        'dispatcher',
        'auth_request',
        'authenticate',
        'got_ping',
        'got_post',
        'send_error',
    ];
}

sub dispatcher {
    my ($kernel, $request) = @_[KERNEL, ARG0];

    my $AUTH_REQUEST = '^AUTH ([[:alnum:]]+) ([[:alnum:]]+) NSMF\/1.0$';
    my $ID_REQUEST   = '^ID ([[:alnum:]])+ ([[:alnum:]])+ NSMF\/1.0$';
    my $PING_REQUEST = '^PING ([[:alnum:]])+ NSMF\/1.0$';
    my $POST_REQUEST = '^POST ([[:alnum:]])+ NSMF\/1.0';

    my $action;

    given($request) {
        when(/$AUTH_REQUEST/i) { $action = 'auth_request' }
        when(/$ID_REQUEST/i)   { $action = 'authenticate' }
        when(/$PING_REQUEST/i) { $action = 'got_ping' }
        when(/$POST_REQUEST/i) { $action = 'got_post' }
        default: {
            say "what?";
            say Dumper $request;
            $action = 'send_error';
        }
    }
    $kernel->yield($action, $request);
}

sub auth_request {
    my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
    print_status  "  - Got AUTH Request: " . $input if $NSMF::DEBUG;

    my @request  = split '\s+', $input;
    my $module   = uc $request[1];
    my $netgroup = $request[2];  

    if ($module ~~ @$modules) {

        say "   Module: $module  Netgroup: $netgroup" if $NSMF::DEBUG;

        $heap->{client}->put("NSMF/1.0 MODULE " . uc($module) . " FOUND\r\n");

        $heap->{nodename} = $module;
        $heap->{netgroup} = $netgroup;


    } else {
        print_status 'Not Found' if $NSMF::DEBUG;
        $heap->{client}->put("NSMF/1.0 MODULE NOT FOUND\r\n");
    }
}

sub authenticate {
    my ($kernel, $session, $heap, $request) = @_[KERNEL, SESSION, HEAP, ARG0];
    
    my @data   = split '\s+', $request;
    my $key    = $data[1];
    my $module = $data[2];
    my $credentials;
    #$key = '';

    eval {
        $credentials = NSMF::Credential->search({ nodename => lc($module) })->next;
    };
    
    if($@) {
        warn '[!!] Database Error';
        return;
    }

    warn 'No credentials found', return unless ( $credentials );

    if ($heap->{nodename} eq $module and defined $heap->{session_id}) {
        print_status  "$module is already authenticated" if $NSMF::DEBUG;
        return;
    }
    
    if ($key ~~ $credentials->password and $heap->{nodename} eq $module) {

        print_status uc($module). " authenticated!" if $NSMF::DEBUG;

        $heap->{session_id} = 1;
        $heap->{status} = 'EST';
        $heap->{client}->put($ACCEPTED."\r\n");
    } else {
        say 'Nodename: ', $heap->{nodename};
        say 'Netgroup: ', $heap->{netgroup};
        say 'Status:   ', $heap->{status};
        say 'Session ID: ', $heap->{session_id};
        $heap->{client}->put("NSMF/1.0 401 Unauthorized\r\n");
    }

}

sub got_ping {
    my ($heap, $input) = @_[HEAP, ARG0];

    return unless $heap->{status} eq 'EST' and $heap->{session_id};

    print_status "  - Got PING" if $NSMF::DEBUG;
    print_status "  -> " . $input;
    my $time = localtime;
    $heap->{client}->put("NSMF/1.0 PONG $time\r\n")
}

sub got_post {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    return unless $heap->{nodename} and $heap->{session_id};

    my @data = split '\n', $request;
    say "Got POST:";
    say Dumper @data;
    say 'This is a post for ' . $heap->{nodename};

    my $module = ModMngr->load($heap->{nodename});
    $module->hello();
}   

sub trigger {
    my ($kernel, $heap, $module) = @_[KERNEL, HEAP, ARG0];
    say "Triggering $module";
}

sub send_error {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $client = $heap->{client};
    warn "[!] Bad Request" if $NSMF::DEBUG;
    $client->put("NSMF/1.0 400 BAD REQUEST\r\n");
}

1;
