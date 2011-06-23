package NSMF::Node::Action;

use strict;
use v5.10;

use POE;
use NSMF::Util;

sub file_watcher {
    my ($self, $settings) = @_;

    print_error "Expected hash ref of parameters" unless ref $settings;

    my $dir      = $settings->{directory}  // print_error "Directory Expected";
    my $time     = $settings->{interval}   // 3;
    my $callback = $settings->{callback}   // print_error "Callback Expected";
    my $regex    = $settings->{pattern}    // print_error "Regex Expected";

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
