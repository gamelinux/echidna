package NSMF::Model::Object;

use strict;
use 5.010;

use base qw(Class::Accessor);
use NSMF::Common::Error;
use Data::Dumper;

sub new {
    my ($class, $args) = @_;

    my $criteria = {};
    for my $key (keys %$args) {
        $criteria->{$key} = $args->{$key} 
            if $key ~~ $class->attributes;
    }

    eval {
        $class->validate($criteria);
    }; if ($@) {
        throw $@->message;
    }

    $class->SUPER::new($args);
}

sub set_properties {
    my ($class, $props) = @_;

    {    
        no strict 'refs';
        *{"${class}::properties"} = sub { $props };
    }   

    $class->mk_accessors(keys %$props);
}

sub required_properties {
    my $class = shift;

    my @required = grep { 
        $_ if ref $class->properties->{$_} 
    } keys %{ $class->properties };

    \@required;
}

sub metadata { shift->properties }
sub attributes { 
    my @keys = keys %{ shift->properties };
    \@keys;
}

sub set {
    my ($self, $method, $arg) = @_;
    
    if (defined $method and exists $self->properties->{$method}) {
        my $type = $self->properties->{$method};
        $type = shift @$type if ref $type eq 'ARRAY';

        eval {
            $self->validate_type($type, $method, $arg);
        }; 
        
        if ($@) {
            throw 'TypeError', $@->message;
        } else {
            $self->SUPER::set($method, $arg);
        }
    } 
    else {
        warn "Unknown $method called on " .ref $self. " object";
    }
}

sub validate_type {
    my ($self, $type, $key, $value) = @_; 

    given($type) {
        when(/ip/) {  
            #croak { message => "IP type expected on '$key' accessor" }
            #    unless $value ~~ /\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\Z/;
        }
        when(/int/) { 
            throw 'ValidationError', "Integer type expected on '$key' accessor"
                unless $value ~~ /\A\d+\Z/;
        }   
        when(/varchar/) {
            throw 'ValidationError', "Varchar type expected on '$key' accessor"
                unless $value ~~ /[a-z0-1.,-_ ]+/i;
        }
        when(/text/) {
            throw 'ValidationError', "Text type expected on '$key' accessor"
                unless $value ~~ /[a-z0-1.,-_ ]+/i;
        }   
        when(/datetime/) {
            throw 'ValidationError', "Datetime type expected on '$key' accessor"
                unless $value ~~ /\A\d{4}\-\d{2}\-\d{2} \d{2}\:\d{2}\:\d{2}\Z/;
        }   
    }   

    return 1;
}

sub validate {
    my ($self, $criteria) = @_;

    return unless ref $criteria eq 'HASH';

    my $props = $self->properties;

    while (my ($key, $value) = each %$criteria) {

        my $type = (ref $props->{$key}) 
                 ? $props->{$key}->[0] 
                 : $props->{$key};

        eval {
            $self->validate_type($type, $key, $value);
        }; if ($@) {
            throw $@->error, $@->message;
        }
    }

    1;
}

1;

