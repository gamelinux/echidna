package NSMF::Common::Logger;

use strict;
use 5.010;

use Carp;
use POSIX qw(strftime);
use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;
use Data::Dumper;

our ($LOG_DIR, $FILENAME);

my $instance;
sub new {
    my ($class, $args) = @_;

    unless (defined $instance) {
        $instance = bless {
            __handler  => _setup($args),
        }, __PACKAGE__;
    }

    $instance;
}

sub _setup {
    my ($args) = @_;

    my $format_callback = sub {
        my %p = @_;
        
        if (defined $args->{timestamp}) {
            my $datetime = strftime('%Y-%m-%d %H:%M:%S', gmtime);
    
            return $datetime . ' ' . $p{message}. "\n";
        } else {
            return $p{message}. "\n";
        }
    };

    my $logger = Log::Dispatch->new(callbacks => $format_callback); 
    
    my $level = $args->{level} // 'debug';
    
    unless ( $logger->level_is_valid( $level ) ) {

        carp "Invalid Level $level"; # die?
        $level = 'debug';
    }

    $LOG_DIR //= $args->{logdir} // croak "Logdir expected";

    unless (-w $LOG_DIR) {
        say "LogDir: " .$LOG_DIR. " ";
        croak "Log dir is not writeable. Be sure to specify logdir."; # die?
    }

    $FILENAME //= $args->{logfile} // croak "Logfile expected";

    my $screen_log = Log::Dispatch::Screen->new(
                    name => 'screen',
                    min_level => $level,
                );

    my $file_log = Log::Dispatch::File->new(
                    name => 'server',
                    min_level => $level,
                    filename => $LOG_DIR .'/'. $FILENAME,
                    mode    => 'append',
                    newline => 1,
                );

    # if ($args->{screen}) {}
    given( $args->{mode} ) {
        when(/debug/i) {
            $logger->add($screen_log);
            $logger->add($file_log);
        }
        when(/screen/i) {
            $logger->add($screen_log);
        }
        default {
            # default should be file
            $logger->add($file_log);
            $logger->add($screen_log);
        }
    }

    return $logger;
}

sub load {
    my ($self, $args) = @_;

    return unless ref $self;

    $self->{__handler} = _setup($args);

    $self;
}

sub debug {
    my ($self, $msg) = @_;

    return unless ref $self eq __PACKAGE__;

    $self->{__handler}->log(level => 'debug', message => $msg);
}

sub info {
    my ($self, $msg) = @_;

    return unless ref $self eq __PACKAGE__;

    $self->{__handler}->log(level => 'info', message => $msg);
}

sub warn {
    my ($self, $msg) = @_;

    return unless ref $self eq __PACKAGE__;

    $self->{__handler}->log(level => 'warning', message => $msg);
}


sub error {
    my ($self, $msg) = @_;

    return unless ref $self eq __PACKAGE__;

    $self->{__handler}->log(level => 'error', message => $msg);
}

sub fatal {
    my ($self, $msg) = @_;

    return unless ref $self eq __PACKAGE__;

    $self->{__handler}->log(level => 'emergency', message => $msg);
}

1;

