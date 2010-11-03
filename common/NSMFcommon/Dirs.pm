package NSMFcommon::Dirs;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
require Exporter;
@EXPORT = qw(ALL);
$VERSION = '0.1';

=head2 check_dir_create_w

Takes $DIR as input:
 If it exists, returns 0.
 If not exists, it tries to create it.
  If it cant create it, die, else return 0.
 

=cut

sub check_dir_create_w {
    # Check that SDIR exists and is writable
    my $DIR = shift;
    unless ( -d "$DIR" ) {
        mkdir "$DIR" or die("Dir $DIR doesn't exist, and I failed to create it!");
        warn "[-] Created dir $DIR\n";
    } else {
        unless ( -w "$DIR" ) {
            die("Directory $DIR isn't writable");
        }
    }
    return 0;
}

1;
