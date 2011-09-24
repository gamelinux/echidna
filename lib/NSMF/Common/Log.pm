package NSMF::Common::Log;

use strict;
use 5.010;

use POSIX qw(strftime);
use Log::Dispatch;
use Log::Dispatch::File;
use Log::Dispatch::Screen;
use Data::Dumper;

my $instance;
sub new {

    my $format_callback = sub {
        my %p = @_;
        my $datetime = strftime('%Y-%m-%d %H:%M:%S', gmtime);

        return $datetime . ' ' . $p{message}. "\n";
    };

    my $logger = Log::Dispatch->new(callbacks => $format_callback); 
    $logger->add(
        Log::Dispatch::Screen->new(
            name => 'screen',
            min_level => 'warning',
        )
    );
    $logger->add(
        Log::Dispatch::File->new(
            name => 'server',
            min_level => 'debug',
            filename => 'echidna.log',
            mode    => 'append',
            newline => 1,
        ),
    );
    
    $instance = bless {
        __handler => $logger,
    }, __PACKAGE__;
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

