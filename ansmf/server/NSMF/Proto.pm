package NSMF::Proto;

use v5.10;
use strict;

use NSMF;
use NSMF::Util;
use NSMF::ModMngr;
use NSMF::Credential;
use NSMF::ConfigMngr;

use POE;

use Date::Format;
use Data::Dumper;
use Compress::Zlib;
use MIME::Base64;
our $VERSION = '0.1';

my $instance;
my $config = NSMF::ConfigMngr->instance;
my $modules = $config->{modules} // [];


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
        'get'
    ];
}

sub dispatcher {
    my ($kernel, $request) = @_[KERNEL, ARG0];

    my $AUTH_REQUEST = '^AUTH (\w+) (\w+) NSMF\/1.0$';
    my $ID_REQUEST   = '^ID (\w)+ (\w)+ NSMF\/1.0$';
    my $PING_REQUEST = '^PING (\w)+ NSMF\/1.0$';
    my $POST_REQUEST = '^POST (\w)+ (\d)+ NSMF\/1.0'."\r\n".'(\w)+';
    my $GET_REQUEST  = '^GET (\w)+ NSMF\/1.0$';

    my $action;

    given($request) {
        when(/$AUTH_REQUEST/i) { $action = 'auth_request' }
        when(/$ID_REQUEST/i)   { $action = 'authenticate' }
        when(/$PING_REQUEST/i) { $action = 'got_ping' }
        when(/$POST_REQUEST/i) { $action = 'got_post' }
        when(/$GET_REQUEST/i)  { $action = 'get' }
        default: {
            say Dumper $request;
            $action = 'send_error';
        }
    }
    $kernel->yield($action, $request);
}

sub auth_request {
    my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
    $input = trim($input);

    say  "  -> Authentication Request: " . $input if $NSMF::DEBUG;

    my $parsed = parse_request(auth => $input);
    unless (ref $parsed eq 'AUTH') {
        $heap->put('NSMF/1.0 400 Bad Request');
        return;
    }

    my $module   = lc $parsed->{nodename};
    my $netgroup = lc $parsed->{netgroup};  

    if ($module ~~ @$modules) {
        say "    [+] Found Module: $module" if $NSMF::DEBUG;

        $heap->{nodename} = $module;
        $heap->{netgroup} = $netgroup;

        $heap->{client}->put("NSMF/1.0 200 OK Accepted\r\n");
    } else {
        say '    = Not Found' if $NSMF::DEBUG;
        $heap->{client}->put("NSMF/1.0 402 Unsuported\r\n");
    }
}

sub authenticate {
    my ($kernel, $session, $heap, $request) = @_[KERNEL, SESSION, HEAP, ARG0];
    
    my @data   = split '\s+', trim($request);
    my $key    = $data[1];
    my $module = lc $data[2];
    my $credentials;

    eval {
        $credentials = NSMF::Credential->search({ 
            nodename => $heap->{nodename},
        })->next;
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
        $heap->{status}     = 'EST';
        $heap->{client}->put("NSMF/1.0 200 OK Accepted\r\n");
        my $mod = NSMF::ModMngr->load($module) or say "Failed to Load Module!";
        
        $heap->{module} = $mod;
        $heap->{module}->hello;
        $heap->{session_id} = $_[SESSION]->ID;

#        POE::Session->create(
#            inline_states => {
#                _start => sub {
#                    $_[KERNEL]->yield('ping');
#                },
#                ping => sub {
#                    say "Hello!";
#                    $_[KERNEL]->delay(ping => 2);
#                }   
#            },
#     );


    } else {
        $heap->{client}->put("NSMF/1.0 401 Unauthorized\r\n");
    }

}

sub got_ping {
    my ($heap, $input) = @_[HEAP, ARG0];

    my @params    = split /\s+/, trim($input);
    my $ping_time = $params[1]; 

    $heap->{ping_recv} = $ping_time if $ping_time;

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $heap->{client}->put("NSMF/1.0 401 Unauthorized\r\n");
        return;
    }

    print_status "  - Got PING" if $NSMF::DEBUG;
    print_status "  -> " . $input;

    if (defined $heap->{module}) {
        say "Session Id: " .$heap->{session_id};
        say "Calilng Hello World Again in the already defined module";
        $heap->{module}->run;
    }
    my $time = time();
    $heap->{client}->put("NSMF/1.0 PONG $time\r\n")

}

sub got_post {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $heap->{client}->put("NSMF/1.0 400 Bad Request\r\n");
        return;
    }

    my $parsed;
    $parsed = parse_request(post => $request);
    return unless ref $parsed eq 'POST';

    #say Dumper $parsed;

    my $data = uncompress(decode_base64( $parsed->{data} ));
    say Dumper $data;
    say "DATA: " .$data;
    say ' -> This is a post for ' . $heap->{nodename};

    my $nodename = uc $heap->{nodename};
   # my $module = NSMF::ModMngr->load($nodename) or say "Failed to Load Module!";
    
}   

sub send_error {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $client = $heap->{client};
    warn "[!] Bad Request" if $NSMF::DEBUG;
    $client->put("NSMF/1.0 400 Bad Request\r\n");
}

sub get {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $heap->{client}->put("NSMF/1.0 400 Bad Request\r\n");
        return;
    }

    my $req = parse_request(get => $request);
    unless (ref $req) { 
        $heap->{client}->put('NSMF/1.0 400 Bad Request');
        return;
    }

    # search data
    my $payload = encode_base64( compress( 'A'x1000 ) );
    $heap->{client}->put('POST ANumbers NSMF/1.0' ."\r\n". $payload);
    
}


1;
