package NSMF::Common::Logger;

use strict;
use 5.010;

use Carp;
use POSIX qw(strftime);
use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;
use Data::Dumper;

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
            $p{message} = strftime($args->{timestamp_format}, gmtime) . ' ' . $p{message};
        }

        return $p{message};
    };

    my $logger = Log::Dispatch->new(callbacks => $format_callback); 

    my $level   = $args->{level}    // 'info';
    my $logfile = $args->{logfile}  // 'stdout';
    my $logdir  = $args->{logdir}   // $LOG_DIR // '/var/log/echidna';

    unless ( $logger->level_is_valid( $level ) ) {
        carp "Invalid Level $level";
        $level = 'info';
    }

    if( $logfile eq 'stdout' ) {
        $logger->add(
            Log::Dispatch::Screen->new(
                name      => 'screen',
                min_level => $level,
                newline   => 1,
            ),
        );
    }
    else {
        $logger->add(
            Log::Dispatch::File->new(
                name      => $profile_name,
                min_level => $level,
                filename  => $logdir. '/' . $logfile,
                mode      => 'append',
                newline   => 1,
            ),
        );

    }

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

