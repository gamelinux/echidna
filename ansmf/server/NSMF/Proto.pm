package NSMF::Proto;

use v5.10;
use strict;

use NSMF;
use NSMF::Data;
use NSMF::Util;
use NSMF::ModMngr;
use NSMF::AuthMngr;
use NSMF::ConfigMngr;

use POE;
use POE::Session;
use POE::Wheel::Run;
use POE::Filter::Reference;

use Carp;
use Data::Dumper;
use Compress::Zlib;
use MIME::Base64;
our $VERSION = '0.1';

my $instance;
my $config = NSMF::ConfigMngr->instance;
my $modules = $config->{modules} // [];

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
        'authenticate',
        'identify',
        'got_ping',
        'got_pong',
        'got_post',
        'send_ping',
        'send_pong',
        'send_error',
        'get',
        'child_output',
        'child_error',
        'child_signal',
        'child_close',
    ];
}

sub dispatcher {
    my ($kernel, $request) = @_[KERNEL, ARG0];

    my $action;
    given($request) {
        when(/$NSMF::Data::AUTH_REQUEST/i) { $action = 'authenticate' }
        when(/$NSMF::Data::ID_REQUEST/i)   { $action = 'identify' }
        when(/$NSMF::Data::PING_REQUEST/i) { $action = 'got_ping' }
        when(/$NSMF::Data::PONG_REQUEST/i) { $action = 'got_pong' }
        when(/$NSMF::Data::POST_REQUEST/i) { $action = 'got_post' }
        when(/$NSMF::Data::GET_REQUEST/i)  { $action = 'get' }
        default: {
            puts Dumper $request;
            $action = 'send_error';
        }
    }
    $kernel->yield($action, $request);
}

sub authenticate {
    my ($kernel, $session, $heap, $input) = @_[KERNEL, SESSION, HEAP, ARG0];
    $input = trim($input);

    puts  "  -> Authentication Request: " . $input;

    my $parsed = parse_request(auth => $input);
    unless (ref $parsed eq 'AUTH') {
        $heap->put($NSMF::Data::BAD_REQUEST);
        return;
    }

    my $agent    = lc $parsed->{agent};
    my $key      = lc $parsed->{key};
    
    eval {
        NSMF::AuthMngr->authenticate($agent, $key);
    };

    if ($@) {
        puts '    => '. $@->{message};
        $heap->{client}->put($NSMF::Data::NOT_SUPPORTED);
        return;
    }

    $heap->{agent}    = $agent;
    puts "    [+] Agent authenticated: $agent";
    $heap->{client}->put($NSMF::Data::OK_ACCEPTED);
}

sub identify {
    my ($kernel, $session, $heap, $request) = @_[KERNEL, SESSION, HEAP, ARG0];
    
    my $parsed = parse_request( id => $request);

    unless (ref $parsed eq 'ID') {
        $heap->put($NSMF::Data::BAD_REQUEST);
        return;
    }
    my $module = trim lc $parsed->{node};
    
    if ($heap->{session_id}) {
        puts  "  <-> $module is already authenticated";
        return;
    }
    
    puts "    -> Requesting Module $module";

    if ($module ~~ @$modules) {

        puts "    ->  " .uc($module). " is supported!";

        $heap->{module_name} = $module;
        $heap->{session_id}  = 1;
        $heap->{status}      = 'EST';

        eval {
            $heap->{module} = NSMF::ModMngr->load(uc $module);
        };

        if (ref $@) {
            puts "    [FAILED] " .$@->{message};
            return;
        }
   
        $heap->{session_id} = $_[SESSION]->ID;
        $heap->{client}->put($NSMF::Data::OK_ACCEPTED);
    } 
    else {
        puts "    [X] $module is not supported";
        $heap->{client}->put($NSMF::Data::NOT_SUPPORTED);
    }

}

sub got_pong {
    my ($kernel, $heap, $input) = @_[KERNEL, HEAP, ARG0];

    puts "  <- Got PONG";
}

sub got_ping {
    my ($kernel, $heap, $input) = @_[KERNEL, HEAP, ARG0];

    my @params    = split /\s+/, trim($input);
    my $ping_time = $params[1]; 

    $heap->{ping_recv} = $ping_time if $ping_time;

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $heap->{client}->put($NSMF::Data::NOT_AUTHORIZED);
        return;
    }

    puts "  <- Got PING";
    $kernel->yield('send_pong');
}

sub child_output {
    my ($kernel, $heap, $output) = @_[KERNEL, HEAP, ARG0];
    puts Dumper $output;
}

sub child_error {
    puts "Child Error: $_[ARG0]";
}

sub child_signal {
    #puts "   * PID: $_[ARG1] exited with status $_[ARG2]";
    my $child = delete $_[HEAP]{children_by_pid}{$_[ARG1]};

    return unless defined $child;

    delete $_[HEAP]{children_by_wid}{$child->ID};
}

sub child_close {
    my $wid = $_[ARG0];
    my $child = delete $_[HEAP]{children_by_wid}{$wid};

    unless (defined $child) {
    #    puts "Wheel Id: $wid closed";
        return;
    }

    #puts "   * PID: " .$child->PID. " closed";
    delete $_[HEAP]{children_by_pid}{$child->PID};
}

sub got_post {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $heap->{client}->put($NSMF::Data::BAD_REQUEST);
        return;
    }

    my $parsed = parse_request(post => $request);

    return unless ref $parsed eq 'POST';

    puts ' -> This is a post for ' . $heap->{module_name};
    puts '    - Type: '. $parsed->{type};
    puts '    - Job Id: ' .$parsed->{job_id};
  

    my $append;
    my $data = $parsed->{data};
    for my $line (@{ $parsed->{data} }) {
        $append .= $line;
    }

    my @sessions = split /\n/, decode_base64 $append;
    
    my $module; 
    unless ($module = $heap->{module}) {
        croak "    Got Post for an uninitialized module!";
    }

    for my $session ( @sessions ) {
        $module->save($session) or next;
        puts " -> Saved\n";
    }
    
}   

sub send_ping {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    puts '  -> Sending PING';
    my $payload = "PING " .time. " NSMF/1.0\r\n";
    $heap->{client}->put($payload);
}

sub send_pong {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    puts '  -> Sending PONG';
    my $payload = "PONG " .time. " NSMF/1.0\r\n";
    $heap->{client}->put($payload);
}

sub send_error {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $client = $heap->{client};
    warn "[!] BAD REQUEST";

    $client->put($NSMF::Data::BAD_REQUEST);
}

sub get {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $heap->{client}->put($NSMF::Data::BAD_REQUEST);
        return;
    }

    my $req = parse_request(get => $request);
    unless (ref $req) { 
        $heap->{client}->put($NSMF::Data::BAD_REQUEST);
        return;
    }

    # search data
    my $payload = encode_base64( compress( 'A'x1000 ) );
    $heap->{client}->put('POST ANumbers NSMF/1.0' ."\r\n". $payload);
    
}

sub call {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    if (ref $heap->{module} ~~ /NSMF::Module/) {

        puts "      ----> Module Call <----"; 
        $heap->{client}->put($NSMF::Data::OK_ACCEPTED);
        return;
        my $child = POE::Wheel::Run->new(
                Program => sub { $heap->{module}->run  },
                StdoutFilter => POE::Filter::Reference->new(),
                StdoutEvent  => 'child_output',
                StderrEvent  => 'child_error',
                CloseEvent   => 'child_close',
                );

        $_[KERNEL]->sig_child($child->PID, 'child_signal');
        $_[HEAP]{children_by_wid}{$child->ID} = $child;
        $_[HEAP]{children_by_pid}{$child->PID} = $child;
    }
    else {
        puts "  [X] Module is not defined";
    }
}

1;
