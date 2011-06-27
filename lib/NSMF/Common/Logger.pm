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
        }, __PACKAGE__;
    }

    return $instance;
}

sub load {
    my ($self, $args) = @_;

    return if ( ref($self) ne __PACKAGE__ );

    __PACKAGE__->new();

    # calculate verbosity level
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

    $self->{_timestamp} = $args->{timestamp} // 0;
    $self->{_timestamp_format} = $args->{timestamp_format} // '%Y-%m-%d %H:%M:%S';
    $self->{_file} = $args->{file} // '';

    if ( -w $args->{file} )
    {
        if ( ! open($self->{_file_handle}, '>' . $self->{_file}) )
        {
            die { state => 'error', message => 'Unable to open log file for writing.' };
        }
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

    @args = map { ref($_) ? Dumper($_) : $_ } @args;

    say $self->time_now() . '[D] ' . join('\n', @args);
}

sub info {
    my ($self, @args) = @_;

    return if ( $self->{_level} < INFO );

    @args = map { ref($_) ? Dumper($_) : $_ } @args;

    say $self->time_now() . '[I] ' . join('\n', @args);
}

sub warn {
    my ($self, @args) = @_;

    return if ( $self->{_level} < WARN );

    @args = map { ref($_) ? Dumper($_) : $_ } @args;

    say $self->time_now() . '[W] ' . join('\n', @args);
}

sub error {
    my ($self, @args) = @_;

    return if ( $self->{_level} < ERROR );

    @args = map { ref($_) ? Dumper($_) : $_ } @args;

    say $self->time_now() . '[E] ' . join('\n', @args);
}


sub fatal {
    my ($self, @args) = @_;

    return if ( $self->{_level} < FATAL );

    @args = map { ref($_) ? Dumper($_) : $_ } @args;

    say $self->time_now() . '[!] ' . join('\n', @args);
    exit;
}

sub time_now
{
    my ($self) = shift;

    my $zone = undef;

    return "" if ( ! defined($self->{_timestamp}) ||
                   $self->{_timestamp} != 1 );

    return strftime($self->{_timestamp_format}, (defined($zone) && ( $zone eq "local" ) ) ? localtime : gmtime) . ' ';
}

sub _log {
    my ($message, $logfile) = @_;
    my $dt = DateTime->now;

    $Data::Dumper::Terse = 1;
    
    $logfile //= 'debug.log';
    open(my $fh, ">>", $logfile) or die $!;
    say $fh $dt->datetime;
    say $fh Dumper $message;
    close $fh;
}
1;
