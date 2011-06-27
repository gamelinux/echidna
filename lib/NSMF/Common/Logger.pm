package NSMF::Common::Logger;

use strict;
use v5.10;

use base qw(Exporter);
use Data::Dumper; 

use constant {
  FATAL => 0,
  ERROR => 1,
  WARN  => 2,
  INFO  => 3,
  DEBUG => 4,
  CHAOS => 5
};

our @EXPORT = qw();

my $instance;

sub new {
    if ( ! defined($instance) )
    {
        $instance = bless {
            _verbosity => INFO,
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

    $self->{_verbosity} = $args->{verbosity} // INFO;
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

sub verbosity {
    my ($self, $arg) = @_;

    $self->{_verbosity} = $arg if ( defined($arg) );

    return $self->{_verbosity};
}

sub debug {
    my ($self, @args) = @_;

    return if ( $self->{_verbosity} < DEBUG );

    $Data::Dumper::Terse = 1;

    my @dump_args = map { ref($_) ? Dumper($_) : $_ } @args;

    say '[D] ' . join('\n', @dump_args);
}

sub info {
    my ($self, @args) = @_;

    return if ( $self->{_verbosity} < INFO );

    say '[I] ' . join('\n', @args);
}

sub warn {
    my ($self, @args) = @_;

    return if ( $self->{_verbosity} < WARN );

    say '[W] ' . join('\n', @args);
}

sub error {
    my ($self, @args) = @_;

    return if ( $self->{_verbosity} < ERROR );

    say '[E] ' . join('\n', @args);
}


sub fatal {
    my ($self, @args) = @_;

    return if ( $self->{_verbosity} < FATAL );

    say '[!] ' . join('\n', @args);
    exit;
}

sub _debug {
    my @args = @_;

    $Data::Dumper::Terse = 1;

    foreach (@args) {
        say Dumper $_;
    }
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
