package NSMF::Common::Logger;

use strict;
use v5.10;

#
# PERL INCLUDES
#
use Data::Dumper; 
use POSIX qw(strftime);

#
# CONSTANTS
#
use constant {
  FATAL => 0,
  ERROR => 1,
  WARN  => 2,
  INFO  => 3,
  DEBUG => 4,
  CHAOS => 5
};

#
# GLOBALS
#
my $instance;

sub new {
    if ( ! defined($instance) )
    {
        $instance = bless {
            _level => INFO,
            _timestamp => undef,
            _timestamp_format => undef,
            _warn_is_fatal => 0,
            _error_is_fatal => 0,
            _file => undef,
            _file_handle => undef,
            _file_writable => 0,
        }, __PACKAGE__;
    }

    return $instance;
}

sub load {
    my ($self, $args) = @_;

    return if ( ref($self) ne __PACKAGE__ );

    __PACKAGE__->new();

    # determine the verbosiy level
    given($args->{level}) {
        when (/fatal/) {
            $self->{_level} = FATAL;
        }
        when (/error/) {
            $self->{_level} = ERROR;
        }
        when (/warn/) {
            $self->{_level} = WARN;
        }
        when (/info/) {
            $self->{_level} = INFO;
        }
        when (/debug/) {
            $self->{_level} = DEBUG;
        }
    };

    # store internal represetation with sane defaults
    $self->{_timestamp}        = $args->{timestamp}         // 0;
    $self->{_timestamp_format} = $args->{timestamp_format}  // '%Y-%m-%d %H:%M:%S';
    $self->{_file}             = $args->{file}              // '';
    $self->{_warn_is_fatal}    = $args->{warn_is_fatal}     // 0;
    $self->{_error_is_fatal}   = $args->{error_is_fatal}    // 0;

    # check if we want to write to a file
    if ( $self->{_file} )
    {
        if ( ! open($self->{_file_handle}, '>' . $self->{_file}) )
        {
            die { state => 'error', message => 'Unable to open log file for writing.' };
        }

        $self->{_file_writable} = 1;
    }

    $instance = $self;

    return $instance;
}

sub level {
    my ($self, $arg) = @_;

    $self->{_level} = $arg if ( defined($arg) );

    return $self->{_level};
}

sub debug {
    my ($self, @args) = @_;

    return if ( $self->{_level} < DEBUG );

    $Data::Dumper::Terse = 1;

    map { $_ = ref($_) ? Dumper($_) : $_ } @args;

    $self->log('[D] ', @args);
}

sub info {
    my ($self, @args) = @_;

    return if ( $self->{_level} < INFO );

    map { $_ = ref($_) ? Dumper($_) : $_ } @args;

    $self->log('[I] ', @args);
}

sub warn {
    my ($self, @args) = @_;

    return if ( $self->{_level} < WARN );

    map { $_ = ref($_) ? Dumper($_) : $_ } @args;

    $self->log('[W] ', @args);

    exit if ( $self->{_warn_is_fatal} );
}

sub error {
    my ($self, @args) = @_;

    return if ( $self->{_level} < ERROR );

    map { $_ = ref($_) ? Dumper($_) : $_ } @args;

    $self->log('[E] ', @args);

    exit if ( $self->{_error_is_fatal} );
}


sub fatal {
    my ($self, @args) = @_;

    return if ( $self->{_level} < FATAL );

    map { $_ = ref($_) ? Dumper($_) : $_ } @args;

    $self->log('[!] ', @args);
    exit;
}


sub prompt {
    my ($self, $message) = @_;

    my $line = $self->time_now() . '[$] ' . $message;

    print $line;

    my $input = <STDIN>;
    chomp($input);

    return $input;
}


sub prompt_with_tabcomplete {
    my ($self, $message, $tab_func) = @_;

    my $line = $self->time_now() . '[$] ' . $message;

    print $line;

    my $input = <STDIN>;
    chomp($input);

    return $input;
}


sub time_now
{
    my ($self) = shift;

    my $zone = undef;

    return '' if ( ! defined($self->{_timestamp}) ||
                   $self->{_timestamp} != 1 );

    return strftime($self->{_timestamp_format}, (defined($zone) && ( $zone eq "local" ) ) ? localtime : gmtime) . ' ';
}


sub log {
    my ($self, $type, @args) = @_;

    my $line = $self->time_now() . $type . join("\n", @args);

    # write to stdout
    say $line;

    # write to file (as appropriate)
    if ( $self->{_file_writable} )
    {
        my $fh = $self->{_file_handle};
        say $fh $line;
    }
}

sub DESTROY {
    my $self = shift;

    if ( $self->{_file_writable} )
    {
        close($self->{_file_handle});
    }
}

1;
