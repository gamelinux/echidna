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
package NSMF::Agent::SNORT;

use warnings;
use strict;
use v5.10;

use base qw(NSMF::Agent::Component);

#
# PERL INCLUDES
#
use Data::Dumper;
use POE;

#
# NSMF INCLUDES
#
use NSMF::Agent;
use NSMF::Common::Util;

#
# GLOBALS
#
our $VERSION = '0.1';

sub new {
    my $class = shift;
    my $node = $class->SUPER::new;
    $node->{__data} = {};

    return $node;
}

# Here is your main()
sub run {
    my ($self, $kernel, $heap) = @_;

    # This provides the necessary data to the Node module for use of the put method
    $self->register($kernel, $heap);

    # At this point the Node is already authenticated so we can begin our work
    print_status("Running test processing..");

    # Hello world!
    $self->hello();

    # PUT is our send method, reuses the $heap->{server}->put that we provided to the super class with the $self->register method
    print_status("Sending a custom ping!");
    $self->put("PING " .time(). " NSMF/1.0");
}

sub  hello {
    print_status "Hello World from SNORT Node!";
}
1;
