package NSMF::Server::Data;

use strict;

# requests
our $AUTH_REQUEST = '^AUTH (\w+) (\w+) NSMF/1.0',
our $ID_REQUEST   = '^ID (\w)+ NSMF\/1.0$',
our $PING_REQUEST = 'PING (\d)+ NSMF/1.0',
our $PONG_REQUEST = 'PONG (\d)+ NSMF/1.0',
our $POST_REQUEST ='^POST (\w)+ (\d)+ NSMF\/1.0'."\n\n".'(\w)+',
our $GET_REQUEST  = '^GET (\w)+ NSMF\/1.0$',

# responses
our $OK_ACCEPTED    = 'NSMF/1.0 200 OK ACCEPTED';
our $BAD_REQUEST    = 'NSMF/1.0 400 BAD REQUEST';
our $NOT_SUPPORTED  = "NSMF/1.0 402 UNSUPPORTED";
our $NOT_AUTHORIZED = "NSMF/1.0 401 UNAUTHORIZED";

1;
