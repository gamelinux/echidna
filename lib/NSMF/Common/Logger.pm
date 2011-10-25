package NSMF::Common::Logger;

use strict;
use 5.010;

use Carp;
use POSIX qw(strftime);
use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;
use Data::Dumper;

our $DEBUG = 1; 
our $LOG_DIR;

my $instance;
sub new {
    my ($class, $args) = @_;

    unless (defined $instance) {
        $instance = bless {
            __handler       => [],
            _warn_is_fatal  => 0,
            _error_is_fatal => 0,
        }, __PACKAGE__;
    }

    return $instance;
}

sub _setup {
    my ($profile_name, $args) = @_;

    # store internal represetation with sane defaults
    $args->{timestamp}        //= 1;
    $args->{timestamp_format} //= '%Y-%m-%d %H:%M:%S';

    my $format_callback = sub {
        my %p = @_;
        
        if ($args->{timestamp} == 1) {
            my $datetime = strftime($args->{timestamp_format}, gmtime);
 
            return $datetime . ' ' . $p{message}. "\n";
        } else {
            return $p{message}. "\n";
        }
    };

    my $logger = Log::Dispatch->new(callbacks => $format_callback); 
    
    my $level = $args->{level} // 'debug';
    
    unless ( $logger->level_is_valid( $level ) ) {
        carp "Invalid Level $level";
        $level = 'debug';
    }

    my ($filepath, $logfile);
    unless (defined $args->{path}) {
        $logfile = $args->{logfile} // croak "Logfile expected";
        
        # use existing logdir if previously set
        if (defined $args->{logdir}) {
            $LOG_DIR = $args->{logdir};
        } 
        else {
            croak "Undefined Log Dir" 
                unless defined $LOG_DIR;
        }
        
        $filepath = $LOG_DIR .'/'. $logfile;

        #croak "Not enough privileges on log filepath $filepath 1"
        #    unless -w $filepath;
    } 
    else {
        $filepath = $args->{path};

        #croak "Not enough privileges on log filepath"
        #    unless -w $filepath;
    }

    if ($DEBUG and $profile_name eq 'default') {
        $logger->add(
            Log::Dispatch::Screen->new(
                name      => 'screen',
                min_level => $level,
            ),
        );
    }

    $logger->add(
        Log::Dispatch::File->new(
            name      => 'server',
            min_level => $level,
            filename  => $filepath,
            mode      => 'append',
            newline   => 1,
        ),
    );

    return $logger;
}

sub load {
    my ($class, $args) = @_;

    my $self;
    if (ref $class eq __PACKAGE__) {
        $self = $class;
    } else {
        $self = __PACKAGE__->new;
    }

    croak 'Expected arguments on ' .__PACKAGE__. ' as hashref'
        unless ref $args eq 'HASH';

    croak "Expected profile 'default' not found"
        unless grep /^default$/, keys %$args;

    my @blacklist = qw( warn_is_fatal error_is_fatal );
    for my $profile_name (keys %$args) {
        next if $profile_name ~~ @blacklist;

        my $profile = $args->{$profile_name};
        push @{ $self->{__handler} },  _setup($profile_name, $profile);
    }

    $self->{_warn_is_fatal}  = $args->{warn_is_fatal}  // 0;
    $self->{_error_is_fatal} = $args->{error_is_fatal} // 0;

    $self;
}

sub debug {
    my ($self, @msgs) = @_;

    return unless ref $self eq __PACKAGE__;
    
    for my $handler (@{ $self->{__handler} }) {
        for my $msg (@msgs) {
            $msg = Dumper($msg) if (ref $msg);
            $handler->log(level => 'debug', message => '[D] '. $msg);
        }
    };
}

sub info {
    my ($self, @msgs) = @_;

    return unless ref $self eq __PACKAGE__;

    for my $handler (@{ $self->{__handler} }) {
        for my $msg (@msgs) {
            $msg = Dumper($msg) if (ref $msg);
            $handler->log(level => 'info', message => '[I] '. $msg);
        }
    }
}

sub warn {
    my ($self, @msgs) = @_;

    return unless ref $self eq __PACKAGE__;

    for my $handler (@{ $self->{__handler} }) {
        for my $msg (@msgs) {
            $msg = Dumper($msg) if (ref $msg);
            $handler->log(level => 'warning', message => '[W] '. $msg);
        }
    }
    exit if ( $self->{_warn_is_fatal} );
}


sub error {
    my ($self, @msgs) = @_;

    return unless ref $self eq __PACKAGE__;
    for my $handler (@{ $self->{__handler} }) {
        for my $msg (@msgs) {
            $msg = Dumper($msg) if (ref $msg);
            $handler->log(level => 'error', message => '[E] '. $msg);
        }
    }
    exit if ( $self->{_error_is_fatal} );
}

sub fatal {
    my ($self, @msgs) = @_;

    return unless ref $self eq __PACKAGE__;

    for my $handler (@{ $self->{__handler} }) {
        for my $msg (@msgs) {
            $msg = Dumper($msg) if (ref $msg);
            $handler->log(level => 'emergency', message => '[F] '. $msg);
        }
    }
    exit;
}

1;

