package NSMF::Proto::JSON;

use v5.10;
use strict;

use NSMF;
use NSMF::Util;
use NSMF::ModMngr;
use NSMF::AuthMngr;
use NSMF::ConfigMngr;

use POE;
use POE::Session;
use POE::Wheel::Run;
use POE::Filter::Reference;

use Date::Format;
use Data::Dumper;
use Compress::Zlib;
use MIME::Base64;

use JSON;

use constant {

  # JSONRPC defined errors
  JSONRPC_ERR_PARSE            => {
      "code" => -32700,
      "message" => "Invalid JSON was received."
  },
  JSONRPC_ERR_INVALID_REQUEST  => {
      "code" => -32600,
      "message" => "The JSON send is not a valid Request object."
  },
  JSONRPC_ERR_METHOD_NOT_FOUND => {
      "code" => -32601,
      "message" => "The method does not exist / is not available."
  },
  JSONRPC_ERR_INVALID_PARAMS   => {
      "code" => -32602,
      "message" => "Invalid method parameters."
  },
  JSONRPC_ERR_INTERNAL         => {
      "code" => -32603,
      "message" => "An internal error encountered."
  },

  #
  # APPLICATION ERRORS
  #

  #
  # GENERAL
  JSONRPC_NSMF_BAD_REQUEST => {
    "code" => -1,
    "message" => "BAD request."
  },

  #
  # AUTH
  JSONRPC_NSMF_AUTH_UNSUPPORTED => {
    "code" => -10,
    "message" => "AUTH unsupported."
  },

  #
  # IDENT
  JSONRPC_NSMF_IDENT_UNSUPPORTED => {
    "code" => -20,
    "message" => "IDENT unsupported."
  },
};

#

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

    return unless ref($self) eq 'NSMF::Proto::JSON';

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

  my $json = {};

  eval {
    $json = decode_json(trim($request));
  };

  if ( $@ ) {
    say("Invalid JSON request: " . $request);
    return;
  }

  if ( exists($json->{"method"}) )
  {
    my $action = $json->{"method"};

    given($json->{"method"}) {
      when(/authenticate/) { }
      when(/identify/) { }
      when(/get/) { }
      when(/ping/) {
        $action = 'got_ping';
      }
      when(/pong/) {
        $action = 'got_pong';
      }
      when(/post/i) {
        $action = 'got_post';
      }
      default: {
        say Dumper($json);
        $action = 'send_error';
      }
    }

    $kernel->yield($action, $json);
  }
}

sub authenticate {
    my ($kernel, $session, $heap, $json) = @_[KERNEL, SESSION, HEAP, ARG0];
    my $self = shift;

    say  "  -> Authentication Request" if $NSMF::DEBUG;

    my ($ret, $response) = $self->jsonrpc_validate($json, [".agent",".secret"]);

    if ( $ret != 0 ) {
      say "Incomplete JSON AUTH request.";
      $heap->{client}->put($response);
      return;
    }

    my $agent  = $json->{params}{agent};
    my $secret = $json->{params}{secret};

    eval {
        NSMF::AuthMngr->authenticate($agent, $secret);
    };

    if ($@) {
        say '    = Not Found ' .$@ if $NSMF::DEBUG;
        $heap->{client}->put($self->json_error_create($json, JSONRPC_NSMF_AUTH_UNSUPPORTED));
        return;
    }

    $heap->{agent}    = $agent;
    say "    [+] Agent authenticated: $agent" if $NSMF::DEBUG;

    $heap->{client}->put($self->json_result_create($json, ""));
}

sub identify {
    my ($kernel, $session, $heap, $json) = @_[KERNEL, SESSION, HEAP, ARG0];
    my $self = shift;

    my ($ret, $response) = $self->jsonrpc_validate($json, [".module",".netgroup"]);

    if ( $ret != 0 ) {
      say "Incomplete JSON ID request.";
      $heap->{client}->put($response);
      return;
    }

    my $module = trim(lc($json->{params}{module}));
    my $netgroup = trim(lc($json->{params}{netgroup}));

    if ($heap->{session_id}) {
        say  "$module is already authenticated" if $NSMF::DEBUG;
        return;
    }

    if ($module ~~ @$modules) {

        say "    ->  " .uc($module). " supported!" if $NSMF::DEBUG;

        $heap->{module_name} = $module;
        $heap->{session_id} = 1;
        $heap->{status}     = 'EST';

        eval {
            $heap->{module} = NSMF::ModMngr->load(uc $module);
        };

        if ($@) {
            say "    [FAILED] Could not load module: $module";
            say $@ if $NSMF::DEBUG;
        }

        $heap->{session_id} = $_[SESSION]->ID;

        if (defined $heap->{module}) {
            # say "Session Id: " .$heap->{session_id};
            # say "Calilng Hello World Again in the already defined module";
            say "      ----> Module Call <----";
            $heap->{client}->put($self->json_result_create($json, "ID accepted"));
            return;
            my $child = POE::Wheel::Run->new(
                Program => sub { $heap->{module}->run  },
                StdoutFilter => POE::Filter::Reference->new(),
                StdoutEvent => "child_output",
                StderrEvent => "child_error",
                CloseEvent  => "child_close",
            );

            $_[KERNEL]->sig_child($child->PID, "child_signal");
            $_[HEAP]{children_by_wid}{$child->ID} = $child;
            $_[HEAP]{children_by_pid}{$child->PID} = $child;
        }
    }
    else {
        $heap->{client}->put($self->json_error_create($json, JSONRPC_NSMF_IDENT_UNSUPPORTED));
    }

}

sub got_pong {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    say "  <- Got PONG" if $NSMF::DEBUG;
}

sub got_ping {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    my $parsed = $self->jsonrpc_validate($json, [".timestamp"]);

    if ( keys %{$parsed} ) {
      say "Incomplete PING request.";
      $heap->{client}->put(encode_json($parsed));
      return;
    }

    my $ping_time = $json->{params}{timestamp};

    $heap->{ping_recv} = $ping_time if $ping_time;

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $heap->{client}->put(encode_json($self->json_result_create($json, "unauthorized")));
        return;
    }

    say "  <- Got PING" if $NSMF::DEBUG;
    $kernel->yield('send_pong', $json);
}

sub child_output {
    my ($kernel, $heap, $output) = @_[KERNEL, HEAP, ARG0];
    say Dumper $output;
}

sub child_error {
    say "Child Error: $_[ARG0]";
}

sub child_signal {
    #say "   * PID: $_[ARG1] exited with status $_[ARG2]";
    my $child = delete $_[HEAP]{children_by_pid}{$_[ARG1]};

    return unless defined $child;

    delete $_[HEAP]{children_by_wid}{$child->ID};
}

sub child_close {
    my $wid = $_[ARG0];
    my $child = delete $_[HEAP]{children_by_wid}{$wid};

    unless (defined $child) {
    #    say "Wheel Id: $wid closed";
        return;
    }

    #say "   * PID: " .$child->PID. " closed";
    delete $_[HEAP]{children_by_pid}{$child->PID};
}

sub got_post {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        $heap->{client}->put("NSMF/1.0 400 BAD REQUEST\r\n");
        return;
    }

    my $parsed = parse_request(post => $request);

    return unless ref $parsed eq 'POST';

    say ' -> This is a post for ' . $heap->{module_name};
    say '    - Type: '. $parsed->{type};
    say '    - Job Id: ' .$parsed->{job_id};

    my $append;
    my $data = $parsed->{data};
    for my $line (@{ $parsed->{data} }) {
        $append .= $line;
    }

    my @sessions = split /\n/, decode_base64 $append;

    my $module = $heap->{module};
    for my $session ( @sessions ) {
        next unless $module->validate( $session );

        $module->save( $session ) or say $module->errstr;
        say "    Session saved";
    }

}

sub send_ping {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    say '  -> Sending PING';
    my $payload = "PING " .time. " NSMF/1.0\r\n";
    $heap->{client}->put($payload);
}

sub send_pong {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    my $self = shift;

    say '  -> Sending PONG';

    my $payload = $self->json_result_create($json, {
        "timestamp" => time()
    });

    $heap->{client}->put(encode_json($payload));
}

sub send_error {
    my ($kernel, $heap, $json) = @_[KERNEL, HEAP, ARG0];
    warn "[!] BAD REQUEST" if $NSMF::DEBUG;
    $heap->{client}->put($self->json_error_create($json, JSONRPC_NSMF_BAD_REQUEST));
}

sub get {
    my ($kernel, $heap, $request) = @_[KERNEL, HEAP, ARG0];

    unless ($heap->{status} eq 'EST' and $heap->{session_id}) {
        say "Sending BAD GET";
        $heap->{client}->put("NSMF/1.0 400 BAD REQUEST\r\n");
        return;
    }

    my $req = parse_request(get => $request);
    unless (ref $req) {
    say 'BAD in GET';
        $heap->{client}->put('NSMF/1.0 400 BAD REQUEST');
        return;
    }

    # search data
    my $payload = encode_base64( compress( 'A'x1000 ) );
    $heap->{client}->put('POST ANumbers NSMF/1.0' ."\r\n". $payload);

}

#
# PRIVATES
#

# TODO: move to a dedicated lib
          #      + (scalar)
          #      * (array)
          #      # (object)
sub jsonrpc_validate
{
  my ($self, $json, $mandatory, $optional) = @_;

  my $type_map = {
    "#" => "HASH",
    "*" => "ARRAY",
    "+" => "SCALAR",
    "." => ""
  };

  if ( ! exists($json->{"params"}) )
  {
    return (1, $self->json_error_create($json, JSONRPC_ERR_INVALID_PARAMS));
  }
  elsif ( ref($json->{"params"}) eq "HASH" )
  {
    # check all mandatory arguments
    for my $arg ( @{ $mandatory } )
    {
      my $type = substr($arg, 0, 1);
      my $param = substr($arg, 1);

      if ( ! defined($json->{"params"}{$param}) )
      {
        return (1, $self->json_error_create($json, JSONRPC_ERR_INVALID_PARAMS));
      }
      elsif ( ref($json->{"params"}{$param}) ne $type_map->{$type} )
      {
        # say "message"=> "Some params are not of the correct type. Expected '" .$param. "' to be of type '" .$type_map->{$type}. "'. Got '" .ref( $json->{params}{$param} ). "'"

        return (1, $self->json_error_create($json, JSONRPC_ERR_INVALID_PARAMS));
      };
    }
  }
  elsif ( ref($json->{"params"}) eq "ARRAY" )
  {
    my $params_by_name = {};

    # check all mandatory arguments
    for my $arg ( @{ $mandatory } )
    {
      my $type = substr($arg, 0, 1);
      my $param = substr($arg, 1);

      # check we have parameters still on the list
      if ( @{ $json->{"params"} } )
      {
        if ( ref( @{ $json->{"params"} }[0]) eq $type_map->{$type} )
        {
          $params_by_name->{$param} = shift( @{$json->{"params"}} );
        }
        else
        {
          # say"Some params are not of the correct type. Expected '" .$param. "' to be of type '" .$type_map->{$type}. "'. Got '" .ref( @{$json->{params}}[0] ). "'"

          return (1, $self->json_error_create($json, JSONRPC_ERR_INVALID_PARAMS));
        }
      }
      else
      {
        return (1, $self->json_error_create($json, JSONRPC_ERR_INVALID_PARAMS));
      }
    }

    # check all optional arguments
    for my $arg ( @{ $optional } )
    {
      my $type = substr($arg, 0, 1);
      my $param = substr($arg, 1);

      # check we have parameters still on the list
      if ( @{ $json->{"params"} } )
      {
        if ( ref( @{ $json->{"params"} }[0]) eq $type_map->{$type} )
        {
          $params_by_name->{$param} = shift( @{$json->{"params"}} );
        }
        else
        {
          #XXX: DEBUG
          # say "Some params are not of the correct type. Expected '" .$param. "' to be of type '" .$type_map->{$type}. "'. Got '" .ref( @{$json->{params}}[0] ). "'"

          return (1, $self->json_error_create($json, JSONRPC_ERR_INVALID_PARAMS));
        };
      }
      else
      {
        last;
      }
    }

    # replace by-position parameters with by-name
    $json->{"params"} = $params_by_name;
  }
  else
  {
    return (1, $self->json_error_create($json, JSONRPC_ERR_INVALID_PARAMS));
  }

  # success
  return (0, {});
}

sub json_response_create
{
  my ($self, $type, $json, $data) = @_;

  # no response should occur if not of type result or error
  return "" if ( ! ($type ~~ ["result", "error"]) );

  # no response should occur if no id was specified (ie. notification)
  return "" if ( ! defined($json) || ! exists($json->{id}) );

  my $result = {};

  $result->{id} = $json->{id};
  $result->{$type} = $data // {};

  return encode_json($result);
}

sub json_result_create
{
  my ($self, $json, $data) = @_;

  return $self->json_response_create("result", $json, $data);
}

sub json_error_create
{
  my ($self, $json, $data) = @_;

  return $self->json_response_create("error", $json, $data);
}

1;
