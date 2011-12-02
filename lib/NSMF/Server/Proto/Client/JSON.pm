#
# This file is part of the NSM framework
#
# Copyright (C) 2010-2011, Edward Fjellskål <edwardfjellskaal@gmail.com>
#                          Eduardo Urias    <windkaiser@gmail.com>
#                          Ian Firns        <firnsy@securixlive.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License Version 2 as
# published by the Free Software Foundation.  You may not use, modify or
# distribute this program under any other version of the GNU General
# Public License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#
package NSMF::Server::Proto::Client::JSON;

use warnings;
use strict;
use v5.10;

#
# PERL INCLUDES
#
use Carp;
use Compress::Zlib;
use Data::Dumper;
use Date::Format;

#
# NSMF INCLUDES
#
use NSMF::Common::JSON;
use NSMF::Common::Util;
use NSMF::Common::Registry;

use NSMF::Server;
use NSMF::Server::AuthMngr;
use NSMF::Server::ModMngr;

#
# GLOBALS
#
my $instance;
my $logger = NSMF::Common::Registry->get('log')
    // carp 'Got an empty config object from Registry';

my $config = NSMF::Common::Registry->get('config')
    // carp 'Got an empty config object from Registry';

my $modules = $config->modules() // [];

sub instance {
    return $instance if ( $instance );

    my ($class) = @_;

    my $self = bless({
        methods => {},
    }, $class);

    $self->init();

    return $self;
}

sub init {
    my ($self) = @_;

    $self->_register_method('authenticate', 0, sub { $self->authenticate(@_); });
    $self->_register_method('ping', 0, sub { $self->ping(@_); });
    $self->_register_method('get_available_components', 0, sub { $self->get_available_components(@_); });
    $self->_register_method('get_available_methods', 0, sub { $self->get_available_methods(@_); });
}

sub client_from_handle {
    my ($self, $handle) = @_;

    my $clients = NSMF::Server->instance()->clients();
    my $client = undef;

    if ( ref($handle) eq 'AnyEvent::Handle' ) {
        $client = $clients->{ fileno( $handle->{fh} ) };
    }
    elsif ( ref($handle) eq 'AnyEvent::Socket' ) {
      $client = $clients->{ fileno($handle) } // undef;
    }

    return $client;
}

sub read {
    my ($self, $handle) = @_;

    $handle->push_read( json => sub { $self->dispatcher(@_); } );
}

sub write {
    my ($self, $handle, $json) = @_;

    return if ( ref($json) ne 'HASH' );

    $handle->push_write( json => $json );
    $handle->push_write( "\n" );
}

sub dispatcher {
    my ($self, $handle, $json) = @_;

    my $action = json_action_get($json);

    # obtain node from handle
    my $client = $self->client_from_handle($handle);
    return if ( ! defined($client) );

    # check if we should respond first
    if ( defined($action->{callback}) ) {
        return $action->{callback}($self, $client, $json);
    }

    if ( exists($json->{method}) ) {
        my $ret;

        eval {
            $self->_execute_method($json->{method}, $client, $json);
        };

        if ( ref($@) ) {
            $self->write($handle, json_error_create($json, $@));
        }
    }
    else {
        $self->write($handle, json_error_create($json, JSONRPC_NSMF_BAD_REQUEST));
    }
}

#
# PRIVATE METHODS
#

sub _register_method {
    my ($self, $method, $acl, $func) = @_;

    # check if the method is already defined
    return 0 if ( defined($self->{methods}{$method}) );

    $logger->debug('Registering client method: ' . $method);
    $self->{methods}{ $method } = {
        acl   => $acl,
        func  => $func,
    }
}

sub _register_methods {
    my ($self, $methods) = @_;

    return if ( ref($methods) ne 'ARRAY' );

    # add each method definition from the array
    foreach my $method ( @{ $methods } ) {
        $self->_register_method($method->{method}, $method->{acl}, $method->{func});
    }
}

sub _execute_method {
    my ($self, $method, $client, $json) = @_;

    # ensure the method is defined
    if ( ! defined($self->{methods}{ $method }) )
    {
        # attempt to dynamically load the class if appropriate
        my ($class, $class_method) = split(/\./, $method);

        $logger->debug("Looking for class: $class");

        if ( ! ($class ~~ @{ $modules }) ) {
            die JSONRPC_ERR_METHOD_NOT_FOUND;
        }

        if ( ! defined($self->{module}{$class}) ) {
            $logger->debug('-> ' . uc($class) . ' supported!');

            eval {
                $self->{module}{$class} = NSMF::Server::ModMngr->load(uc($class));
                $self->_register_methods( $self->{module}{$class}->get_registered_methods() );
            };

            if ($@) {
                $logger->error('Could not load module type: ' . $class);
                $logger->debug($@);
                die JSONRPC_NSMF_GET_UNSUPPORTED;
            }

            if ( ! defined($self->{methods}{ $method }) )
            {
                die JSONRPC_ERR_METHOD_NOT_FOUND;
            }
        }
    };

    # ensure the caller has sufficient privilege
    if ( $self->{methods}{ $method }{acl} ) {
        return if ( $client->{details}{acl} < $self->{methods}{$method}{acl} );
    }

    $logger->debug('Calling from client: ' . $method);

    # finally call the method now
    $self->{methods}{ $method }{func}->($client, $json, sub {
        my $result = shift;

        $self->write( $client->{handle}, json_result_create($json, $result) );
    });
}

sub _is_authenticated {
    my ($self, $node) = @_;

    return ( ( $node->{status} eq 'EST' ) &&
             ( $node->{session_key} ) );
}

#
# CORE METHODS
#

sub authenticate {
    my ($self, $client, $json, $callback) = @_;

    if ( $client->{status} ne 'REQ' ) {
        die { object => JSONRPC_NSMF_UNAUTHORIZED };
    }

    $logger->debug('Authentication Request');

    # authenticate the node
    eval {
        json_validate($json, ['$client','$secret']);
    };

    if ( ref($@) ) {
        $logger->error('Incomplete JSON AUTH request. ' . $@->{message});
        die $@;
    }

    my $client_details = {};

    eval {
        $client_details = NSMF::Server::AuthMngr->authenticate_client($json->{params}{client}, $json->{params}{secret});
    };

    if ($@) {
        $logger->error('Client authentication request unsupported: ', $@);
        die { object => JSONRPC_NSMF_AUTH_UNSUPPORTED };
    }

    $client->{status} = 'EST';
    $client->{name} = $client;
    $client->{acl} = $client_details->{level};
    $client->{details} = $client_details;
    $client->{module} = {};

    # generate the session key
    my @keyspace = ('a'..'z', 'A'..'Z', 0..9);
    $client->{session_key} = join('', map $keyspace[rand @keyspace], 0..32);


    my $db = NSMF::Server->database();
#    $db->update({ node => { state => 1 } }, { id => $node->{details}{id} });

    $callback->( $client_details );
}

sub get_available_components {
    my ($self, $client, $json, $callback) = @_;

    # ensure we are authenticated
    if ( ! $self->_is_authenticated($client) ) {
        die JSONRPC_NSMF_BAD_REQUEST;
    }

    $callback->( $modules );
}

sub get_available_methods {
    my ($self, $client, $json, $callback) = @_;

    # ensure we are authenticated
    if ( ! $self->_is_authenticated($client) ) {
        die JSONRPC_NSMF_BAD_REQUEST;
    }

    $callback->( keys( %{ $self->{methods} } ) );
}

sub ping {
    my ($self, $client, $json, $callback) = @_;

    # ensure we are authenticated
    if ( ! $self->_is_authenticated($client) ) {
        die JSONRPC_NSMF_BAD_REQUEST;
    }

    $logger->debug('  <- Got PING');

#   $kernel->post(transfer_mngr => 'queue_status');

    eval {
        json_validate($json, ['$timestamp']);
    };

    if ( ref $@ ) {
        $logger->error('Incomplete PING request. ' . $@->{message});
        die $@;
    }

    my $ping_time = $json->{params}{timestamp};

    $client->{ping_recv} = $ping_time if $ping_time;

    $logger->debug('  -> Sending PONG');

    $callback->( { timestamp => time() } );
}


#sub get {
#    my ($self, $client, $json) = @_;
#
#    if ( $heap->{status} ne 'EST' || ! $heap->{session_key}) {
#        $heap->{client}->put(json_result_create($json, 'Bad request'));
#        return;
#    }
#
#    eval {
#        my ($ret, $response) = json_validate($json, ['$type', '$jobid', '%data']);
#    };
#
#    if ( ref($@) ) {
#      $logger->error('Incomplete GET request. ' . $@->{message});
#      $heap->{client}->put($@->{object});
#      return;
#    }
#
#    my $module_type = $json->{params}{type};
#
#    $logger->debug('This is a GET for ' . $module_type);
#
#    my $modules_allowed = ["core", @{ $modules }];
#
#    if ( $module_type ~~ @{ $modules_allowed } ) {
#        # dyamically load module as required
#        if ( ! defined($heap->{module}{$module_type}) ) {
#            $logger->debug("-> " .uc($module_type). " supported!");
#
#            eval {
#                $heap->{module}{$module_type} = NSMF::Server::ModMngr->load(uc($module_type), $heap->{acl});
#            };
#
#            if ($@) {
#                $logger->error('Could not load module type: ' . $module_type);
#                $logger->debug($@);
#                $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_GET_UNSUPPORTED));
#                return;
#            }
#        }
#
#        if ( defined($heap->{module}{$module_type}) ) {
#            $logger->debug("Module Called");
#
#            my $ret = undef;
#
#            eval {
#                $ret = $heap->{module}{$module_type}->get( $json->{params}{data}, sub { 
#                    my $ret = shift;
#                    my $response = json_result_create($json, $ret);
#
#                    # don't reply with empty strings
#                    if ( $response ne '' ) {
#                        $heap->{client}->put($response);
#                    }
#                });
#            };
#
#            if ( $@ ) {
#                $logger->error($@);
#                my $response = json_error_create($json, {
#                    message => $@->{message},
#                    code => $@->{code}
#                });
#
#                # don't reply with empty strings
#                if ( $response ne '' ) {
#                    $heap->{client}->put($response);
#                }
#            }
#        }
#    }
#    # module is not supported
#    else {
#        $heap->{client}->put(json_error_create($json, JSONRPC_NSMF_GET_UNSUPPORTED));
#    }
#}

1;
