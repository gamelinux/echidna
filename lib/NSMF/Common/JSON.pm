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
package NSMF::Common::JSON;

use warnings;
use strict;
use v5.10;

use base qw(Exporter);

#
# PERL INCLUDES
#
use Carp qw(croak);
use JSON;

#
# NSMF INCLUDES
#
use NSMF::Common::Util;
use NSMF::Common::Logger;

#
# CONSTANTS
#
use constant {
  # JSONRPC defined errors
  JSONRPC_ERR_PARSE            => {
      code => -32700,
      message => 'Invalid JSON was received.'
  },
  JSONRPC_ERR_INVALID_REQUEST  => {
      code => -32600,
      message => 'The JSON sent is not a valid Request object.'
  },
  JSONRPC_ERR_METHOD_NOT_FOUND => {
      code => -32601,
      message => 'The method does not exist / is not available.'
  },
  JSONRPC_ERR_INVALID_PARAMS   => {
      code => -32602,
      message => 'Invalid method parameters.'
  },
  JSONRPC_ERR_INTERNAL         => {
      code => -32603,
      message => 'An internal error encountered.'
  },

  #
  # APPLICATION ERRORS
  #

  #
  # GENERAL
  JSONRPC_NSMF_BAD_REQUEST => {
    code => -1,
    message => 'BAD request.'
  },

  JSONRPC_NSMF_UNAUTHORIZED => {
    code => -2,
    message => 'Unauthorized.'
  },

  #
  # AUTH
  JSONRPC_NSMF_AUTH_UNSUPPORTED => {
    code => -10,
    message => 'AUTH unsupported.'
  },

  #
  # IDENT
  JSONRPC_NSMF_IDENT_UNSUPPORTED => {
    code => -20,
    message => 'IDENT unsupported.'
  },
  JSONRPC_NSMF_IDENT_REGISTERED => {
    code => -21,
    message => 'IDENT already registered.'
  },
  JSONRPC_NSMF_IDENT_INCONSISTENT => {
    code => -22,
    message => 'IDENT details not consistent with registration.'
  },

  #
  # GET
  JSONRPC_NSMF_GET_UNSUPPORTED => {
    code => -30,
    message => 'GET module unsupported.'
  },

  # TRANSFER
  JSONRPC_NSMF_PCAP_NOT_FOUND => {
    code => -50,
    message => 'PCAP data not found in the node requested.',
  },
};

#
# GLOBALS
#
our @EXPORT = qw(
    json_decode
    json_encode
    json_validate
    json_message_create
    json_method_create
    json_notification_create
    json_response_create
    json_result_create
    json_error_create
    json_action_get
    JSONRPC_ERR_PARSE
    JSONRPC_ERR_INVALID_REQUEST
    JSONRPC_ERR_METHOD_NOT_FOUND
    JSONRPC_ERR_INVALID_PARAMS
    JSONRPC_ERR_INTERNAL
    JSONRPC_NSMF_BAD_REQUEST
    JSONRPC_NSMF_UNAUTHORIZED
    JSONRPC_NSMF_AUTH_UNSUPPORTED
    JSONRPC_NSMF_IDENT_UNSUPPORTED
    JSONRPC_NSMF_IDENT_REGISTERED
    JSONRPC_NSMF_IDENT_INCONSISTENT
    JSONRPC_NSMF_PCAP_NOT_FOUND
    JSONRPC_NSMF_GET_UNSUPPORTED
);

my $logger = NSMF::Common::Logger->new();
my $method_map = {};

#
# JSON ENCODE/DECODE WRAPPERS
#

sub json_decode {
    my $ref = shift;

    $logger->debug($ref);

    my $decoded = decode_json($ref);

    return $decoded;
}


sub json_encode {
    my $ref = shift;

    my $encoded = encode_json($ref);

    $logger->debug($encoded);

    return $encoded;
}

#
# JSON RPC VALIDATION
#

# function will modifiy JSON object in place
# function will raise exception via 'die' perhaps should be 'warn' on invalidation
# key lookup (need to change)
# wrap in eval {}
#      $ (scalar)
#      @ (array)
#      % (object)
#
sub jsonrpc_validate
{
    my ($json, $mandatory, $optional) = @_;

    my $type_map = {
        '%' => "HASH",
        '@' => "ARRAY",
        '$' => "",
        "#" => "HASH",
        "*" => "ARRAY",
        "+" => "SCALAR",
        "." => ""
    };

    if ( ! exists($json->{"params"}) )
    {
        die {
            status => 'error',
            message => 'No params defined.',
            object => json_error_create($json, JSONRPC_ERR_INVALID_PARAMS)
        };
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
                die {
                    status => 'error',
                    message => 'Mandatory param"' . $param . '" not found.',
                    object => json_error_create($json, JSONRPC_ERR_INVALID_PARAMS)
                };
            }
            elsif ( ref($json->{"params"}{$param}) ne $type_map->{$type} )
            {
                die {
                    status => 'error',
                    message => 'Some params are not of the correct type. Expected "' . $param . '" to be of type "' .$type_map->{$type}. '". Got "' .ref( $json->{params}{$param} ). '"',
                    object => json_error_create($json, JSONRPC_ERR_INVALID_PARAMS)
                };
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
                    die {
                        status => 'error',
                        message => 'Some params are not of the correct type. Expected "' . $param . '" to be of type "' .$type_map->{$type}. '". Got "' .ref( @{$json->{params}}[0] ). '"',
                        object => json_error_create($json, JSONRPC_ERR_INVALID_PARAMS)
                    };
                }
            }
            else
            {
                die {
                    status => 'error',
                    message => 'Some params are not of the correct type. Expected "' . $param . '" to be of type "' .$type_map->{$type}. '". Got "' .ref( @{$json->{params}}[0] ). '"',
                    object => json_error_create($json, JSONRPC_ERR_INVALID_PARAMS)
                };
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
                    die {
                        status => 'error',
                        message => 'Some params are not of the correct type. Expected "' . $param . '" to be of type "' .$type_map->{$type}. '". Got "' .ref( @{$json->{params}}[0] ). '"',
                        object => json_error_create($json, JSONRPC_ERR_INVALID_PARAMS)
                    };
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
        die {
            status => 'error',
            message => 'Specified params corrupted or of unknown type.',
            object => json_error_create($json, JSONRPC_ERR_INVALID_PARAMS)
        };
    }
}

#
# JSON RPC RESPONSE CREATION
#
sub json_response_create
{
    my ($type, $json, $data) = @_;

    # no response should occur if not of type result or error
    return '' if ( ! ($type ~~ ['result', 'error']) );

    # no response should occur if no id was specified (ie. notification)
    return '' if ( ! defined($json) || ! exists($json->{id}) );

    my $result = {
        jsonrpc => '2.0',
        id => $json->{id},
        $type => $data // {}
    };

    return encode_json($result);
}

sub json_result_create
{
    my ($json, $data) = @_;

    return json_response_create('result', $json, $data);
}

sub json_error_create
{
    my ($json, $data) = @_;

    return json_response_create('error', $json, $data);
}

#
# JSON RPC MESSAGE CREATION
#
sub json_message_create
{
    my ($method, $params, $callback) = @_;

    my $payload;

    # a valid callback will invoke creation of JSON RPC method
    if( ref($callback) eq 'CODE' ) {
        $logger->debug('Creating JSON RPC method.');
        $payload = json_method_create($method, $params, $callback);
    }
    # otherwise it will be a JSON RPC notification
    else {
        $logger->debug('Creating JSON RPC notification.');
        $payload = json_notification_create($method, $params);
    }

    return $payload;
}


sub json_method_create
{
    my ($method, $params, $callback) = @_;

    my $id = int(rand(65536));

    while ( defined($method_map->{$id}) )
    {
        $id = int(rand(65536));
    }

    $method_map->{$id} = {
      method => $method,
      callback => $callback
    };

    return {
        jsonrpc => '2.0',
        method => $method,
        params => $params // '',
        id => $id
    };
}

sub json_notification_create
{
    my ($method, $params) = @_;

    return {
        jsonrpc => '2.0',
        method => $method,
        params => $params // '',
    };
}

sub json_action_get
{
    my ($json) = @_;

    if ( ! defined_args($json->{id}) &&
         ! defined_args($json->{method}) )
    {
        croak({
            status => 'error',
            message => 'Unable to determine JSON RPC intent.'
        });
    }

    my $method = undef;
    my $callback = undef;

#    $logger->debug($json);

    if ( defined($json->{id}) &&
         defined($method_map->{$json->{id}}) )
    {
        $method = $method_map->{$json->{id}}{method};
        $callback = $method_map->{$json->{id}}{callback};

        delete($method_map->{$json->{id}});
    }
    elsif ( defined($json->{method}) )
    {
        $method = $json->{method};
    }
    else
    {
        croak({
            status => 'error',
            message => 'Unable to determine JSON RPC intent. Possible replay of ID.'
        });
    }

    return {
        method => $method,
        callback => $callback
    };
}

1;
