package NSMF::ModMngr;

use NSMF;
use NSMF::ConfigMngr;
use NSMF::Module::CXTRACKER;
use NSMF::Util;
use Data::Dumper;
use Carp;

use strict;
use v5.10;

sub load {
    my ($module_name) = @_;
 
    my $module_path;
    my $config = NSMF::ConfigMngr->instance;
    my $modules = $config->{modules};

    if ($module_name ~~ @$modules) {
    
        $module_path = 'NSMF::Module::' . uc($module_name);
        eval "use $module_path";

        if($@) {
            print_error "Failed to Load Module $module_name";
        } else {
            return $module_path->new;
        }
    }

    croak "No Modules enabled"; 
}

1;
