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
package NSMF::Server::ScriptHelper;

use strict;
use 5.010;
use Carp;

use Data::Dumper;
use NSMF::Common::Logger;
use NSMF::Server::ConfigMngr;

use base qw(Exporter);
our @EXPORT = qw(output fail);

our $LOG_PATH = File::Spec->catdir("logs");
our $CONFIG_PATH = File::Spec->catfile('etc',  'server.yaml');

$NSMF::Common::Logger::LOG_DIR = $LOG_PATH;

my $map = {};
$map->{config} = NSMF::Server::ConfigMngr->load($CONFIG_PATH);
$map->{logger} = NSMF::Common::Logger->load($map->{config}{config}{log});

sub get {
    my ($class, $module) = @_;

    return $map->{$module} if exists $map->{$module};
    croak "Module Not Found on " .__PACKAGE__;
}


sub output {
    my (@msg) = @_;
    
    $map->{logger}->debug(@msg) if exists $map->{logger};
    say for @msg;
}

sub fail {
    my (@msg) = @_;

    $map->{logger}->debug(@msg) if exists $map->{logger};
    say for @msg;
    exit;
}

1;
