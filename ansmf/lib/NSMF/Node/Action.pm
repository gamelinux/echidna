package NSMF::Node::Action;

use strict;
use v5.10;

use POE;
use NSMF::Util;
use NSMF::Common::Logger;

my $logger = NSMF::Common::Logger->new();

sub file_watcher {
    my ($self, $settings) = @_;

    $logger->fatal('Expected hash ref of parameters') if ( ! ref($settings) );

    my $dir      = $settings->{directory}  // $logger->fatal('Directory Expected');
    my $time     = $settings->{interval}   // 3;
    my $callback = $settings->{callback}   // $logger->fatal('Callback Expected');
    my $regex    = $settings->{pattern}    // $logger->fatal('Regex Expected');

    return POE::Session->create(
        inline_states => {
            _start => sub { 
                $_[KERNEL]->yield('watch'); 
                $_[KERNEL]->alias_set('file_seeker');
            },
            watch => sub {
                my ($kernel) = $_[KERNEL];
                my $file_back;
                opendir my $dh, $dir or die "Could not open $dir";
                while ( my $file = readdir($dh)) {
                    if ( -f "$dir/$file" and $file =~ /$regex/) {
                        $file_back = $dir . $file;
                        last;
                    }
                } 
                closedir $dh;
                $self->$callback($file_back);
                $kernel->delay( watch => $time);
            },
        }
    );
}

1;
