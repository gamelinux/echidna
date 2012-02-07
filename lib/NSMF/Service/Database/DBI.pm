package NSMF::Service::Database::DBI;

use strict;
use 5.010;

use base qw(NSMF::Service::Database::Base);

use AnyEvent;
use AnyEvent::DBI;
use Carp;

use Data::Dumper;
use NSMF::Model;
use NSMF::Common::Util;
use NSMF::Common::Error;

use constant {
    ModelNotFound => 'Failed to load module',
};

my $instance;
sub new {
    my ($class, $args) = @_;

    unless (ref $instance eq __PACKAGE__) {
        $instance = bless {
            __debug   => 0,
            __pool    => {}, # handles hash
            __idle    => [], # handle pids idle
            __running => {}, # handle pids running
            __counter => 0,  #      
            __total   => 0,  # handles created
            __window_size => 1000,
            __return_objects => 0,
            __loaded_models => [],
        }, $class;

        $instance->_setup($args);
    }

    $instance;
}

sub _setup {
    my ($self, $args) = @_;

    if ( ! ref($args) ) {
        warn "Expected ref args";
    };

    $instance->{__total} = $args->{pool_size} // 10;
    croak "Size should be an integer" 
        unless $instance->{__total} ~~ /\d+/;

    croak "Driver type not found!"   if ( ! defined($args->{type}) );
    croak "Database name not found!" if ( ! defined($args->{name}) );
    croak "User not found!"          if ( ! defined($args->{user}) );
    croak "Password not found!"      if ( ! defined($args->{pass}) );

    # dsn
    my $dtype               = $args->{type};
    my $database            = $args->{name};
    $instance->{__user}     = $args->{user};
    $instance->{__password} = $args->{pass};
    $instance->{__debug}    = $args->{debug} // 0;

    $instance->{__dsn} = join(":", "dbi", $args->{type}, $args->{name});

    for (1..$instance->{__total}) {
        my $dbi = new AnyEvent::DBI 
                      $instance->{__dsn}, 
                      $instance->{__user}, 
                      $instance->{__password},
                      PrintError => 0,
                      on_error => sub {
                          say "DBI Error: $@ at $_[1]:$_[2]";
                      };

        $instance->{__pool}->{$dbi->{child_pid}} = $dbi;

    }

    my @pids = keys %{ $instance->{__pool} };

    if (scalar @pids < 1) {
        croak "Error - Failed to create database handlers";
    }

    $instance->{__idle} = \@pids;
    $instance->{__running}->{$_} = 0 for @pids;

    $instance->_autoload_models();
}

sub pool_size {
    my $self = shift;
    keys %{ $self->{__pool} } // die;
}

my $w;
sub fire_watcher {
    my ($self, $time) = @_;

    return unless ref $self;

    unless (defined $time ~~ /\A\d+\Z/) {
        warn "Expected integer value on " .__PACKAGE__. '->fire_watcher';
        return;
    }

    $w = AE::timer 1, $time, sub {
       say  "Running: $self->{__running} " .(keys %{$self->{__running}}). " (".join(", ", (keys %{$self->{__running}})). ")";
    };
}

sub fetch {
    my $self = shift;

    if ($self->{__debug}) {
        say  "Running: $self->{__running} " .(keys %{$self->{__running}})
           . " (".join(", ", (keys %{$self->{__running}})). ")";
    }

    # pool is empty
    my $dbh;
    if (scalar @{ $self->{__idle} } < 1) {
        my $pid = $self->_reuse_pid;
        $dbh  = $self->{__pool}->{$pid};
        $self->{__running}->{$pid} += 1;
    } else {
        my $pid = shift @{ $self->{__idle} };
        $dbh    = $self->{__pool}->{$pid};
        $self->{__running}->{$pid} += 1;
    }

    unless (ref $dbh eq 'AnyEvent::DBI') {
        if ($self->{__debug}) {
            say "Counter: " .$self->{__counter};
            say Dumper "Idle: ", $self->{__idle};
            say Dumper "Running: ", keys %{ $self->{__running} };
        }
        die "HandleFetchError - Could not fetch valid handler";
    }

    if ($self->{__debug}) {
        say "Selected PID: " .$dbh->{child_pid};
        say "Fetched:      " .ref $dbh;
        my @pids_current = @{ $self->{__idle} };
        say "Now " .scalar @pids_current. " handlers available";
        say;
    }

    return $dbh;
}

sub _reuse_pid {
    my ($self) = @_;

    my @pids = sort keys %{ $self->{__running} };
    $self->{__counter} %= $self->{__total};
    my $pid = $pids[$self->{__counter}];
    $self->{__counter} += 1;

    say "Reusing pid $pid" if $self->{__debug};

    return $pid;
}

sub sleep {
    my ($self, $interval, $cb) = @_;

    die "TypeError - Expected integer value" 
        unless defined $interval ~~ /\d+/;

    $self->_exec_query("SELECT SLEEP($interval)", undef, $cb);
}

sub _exec_query {
    my ($self, $sql, $model, $cb) = @_;

    my $dbh = $self->fetch;

    my $cv = AE::cv;
    if (ref $cb eq 'CODE') {
        $cv->cb(sub {
            my $cv = shift;
            $cb->($cv->recv);
        });
    }

    say Dumper $self->{__running} if $self->{__debug};
    say "SQL: $sql" if $self->{__debug};
    $dbh->exec($sql, sub {
        my ($dbh, $rows, $rv) = @_;
        $#_ or die "Internal Failure $@";

        $self->return_handle($dbh) 
            or die "Failed to return handler $@";

        if (defined $model) {
            my @result;
            for my $row (@$rows) {
                push @result, $self->_map_properties($model, $row);
            }

            $cv->send(\@result);
        }
        else {
            $cv->send(@$rows);
        }
    });

    $cv;
}

sub build_query {
    my ($self, $model_type, $criteria, $cb) = @_;

    my $model = $self->_load_model($model_type);
    my $sql   = $self->_mk_query_select($model, $criteria);

    return $sql;
}

sub search {
    my ($self, $model_type, $criteria, $cb) = @_;

    my $model = $self->_load_model($model_type);

    $self->_validate_criteria($model, $criteria);

    my $sql = $self->_mk_query_select($model, $criteria);

    $self->_exec_query($sql, $model, $cb);
}

sub count {
    my ($self, $model_type, $cb) = @_;

    croak "ModelNotFound - The model requested does not exist" 
        unless 'NSMF::Model::' .ucfirst($model_type) ~~ [NSMF::Model->objects];

    $self->_exec_query("SELECT COUNT(*) FROM $model_type", undef, $cb);
}

sub map_objects {
    my ($self, $enable) = @_;

    if ($enable) {
        $self->{__return_objects} = 1;
    } else {
        $self->{__return_objects} = 0;
    }
}

sub return_handle {
    my ($self, $dbh) = @_;

    croak 'Error - Failed to close db handle'
        unless ref $dbh eq 'AnyEvent::DBI';

    my $pid = $dbh->{child_pid};

    my $idx = 0;
    for my $pid_running (sort keys %{ $self->{__running} }) {
        last if $pid_running ~~ qr/\A$pid\Z/;
        $idx += 1;
    }

    $self->{__running}->{$pid} -= 1;
    if ($self->{__running}->{$pid} == 0) {
        push @{ $self->{__idle} }, $pid."";
    }

    1;
}

sub window_size {
    my ($self, $wsize) = @_;

    if (defined $wsize and $wsize ~~ /\A\d+\Z/) {
        $self->{__window_size} = $wsize;
    } else {
        return $self->{__window_size};
    }
}

sub search_iter {
    my ($self, $model_type, $criteria) = @_;

    my $dbi   = $self->fetch;
    my $model = $self->_load_model($model_type);

    $self->_validate_criteria($model, $criteria);

    my $sql   = $self->_mk_query_select($model, $criteria);

    my $limit_query = $sql. " LIMIT 0, " .$self->window_size;
    my $result = $self->_exec_query($limit_query, $model, undef)->recv;

    my $idx    = 0; # array index
    my $offset = 0; # limit offset 
    return sub {
        if ($idx == $self->window_size) {
            $offset += $self->window_size;

            $limit_query = $sql. " LIMIT " .$offset. ", " .$self->window_size;

            splice @$result;
            $result = $self->_exec_query($limit_query, $model, undef)->recv;

            $idx = 0;
            my $object = $result->[$idx];
            $idx += 1;  # this can be omitted using $result[$idx++]

            return $object;
        } else {
            my $object = $result->[$idx];
            $idx += 1;

            return $object;
        }
    };
}

sub _autoload_models {
    my ($self) = @_;

    for my $model_path (NSMF::Model->objects) {
        $self->_require_model($model_path);
    }
}

sub _require_model {
    my ($self, $model_path) = @_;

    eval qq{require $model_path}; if ($@) {
        throw 'ModelNotFound', $@;
    }

    push @{ $self->{__loaded_models} }, $model_path;
}

sub _load_model {
    my ($self, $model) = @_;

    my $model_path = 'NSMF::Model::' .ucfirst($model);
    unless ($model_path ~~ $self->{__loaded_models}) {
        eval qq{require $model_path}; if ($@) {
            throw "Failed to load $model_path [$@]";
        }
    }

    return $model_path;
}

sub _clean_criteria {
    my ($model, $criteria) = @_;

    for my $key (keys %$criteria) {
        delete $criteria->{$key} unless $key ~~ $model->attributes;
    }

    return $criteria;
}

sub _mk_query_select {
    my ($self, $model, $criteria) = @_;

    my $table = lc $1 if $model =~ /::(\w+)$/;

    $criteria = _clean_criteria($model, $criteria);

    return "SELECT " .join(", ", @{ $model->attributes })
          ." FROM " .$table. " " .$self->create_filter($criteria);
}

sub _mk_query_count {
    my ($self, $model, $criteria) = @_;

    my $table = lc $1 if $model =~ /::(\w+)$/;
    $criteria = _clean_criteria($model, $criteria);

    return "SELECT COUNT(*) FROM " .$table. " " .$self->create_filter($criteria);
}

sub _mk_query_insert {
    my ($self, $object) = @_;

    my @fields = sort keys %{ $object->properties };
    my @values = map { "'".$object->get($_)."'" } @fields;
    my $model = ref $object;
    my $table = lc $1 if $model =~ /::(\w+)$/;

    return "INSERT INTO " .lc $table. "(".join(", ", @fields). ") VALUES(" .join(", ", @values). ")";
}

sub _mk_query_update {
    my ($self, $model, $criteria, $data) = @_;

    my $table = lc $1 if $model =~ /::(\w+)$/;
    my $data  = _clean_criteria($model, $data);
    $criteria = _clean_criteria($model, $criteria);

    my $query = "UPDATE $table SET ";

    my @pairs;
    for my $key (keys %{ $data }) {
        push @pairs, "$key = '$data->{$key}'";
    }

    $query .= join(", ", @pairs);
    $query .= " " .$self->create_filter($criteria);
}

sub _map_properties {
    my ($self, $model, $row) = @_;

    my $hash = {};
    $hash->{$_} = shift @$row for (@{ $model->attributes });

    return $model->new($hash) if $self->{__return_objects};

    $hash
}

sub _validate_criteria {
    my ($self, $model, $criteria) = @_;

    eval {
        $model->validate($criteria);
    }; if ($@) {
        throw $@->message;
    }
}

sub _validate_object {
    my ($self, $model, $object) = @_;

    my @required = grep {
        $_ if ref $model->properties->{$_} eq 'ARRAY'
    } @{ $model->attributes };

    for my $key (keys %{ $model->properties }) {
        if ($key ~~ @required) {
            my $type  = shift @{ $model->properties->{$key} };
            my $value;
            if (ref $object eq $model) {
                $value = $object->get($key);
            }
            else {
                $value = $object->{$key};
            }

            $model->validate_type($type, $key, $value); 
        }
    }
}

sub insert {
    my ($self, $model_type, $data, $cb) = @_;

    my $model = $self->_load_model($model_type);

    eval {
        $self->_validate_object($model, $data);
    }; if ($@) {
        throw $@->message;
    }

    my $sql = $self->_mk_query_insert($data);
    $self->_exec_query($sql, undef, $cb);
}

sub update {
    my ($self, $model_type, $criteria, $data, $cb) = @_;

    my $model = $self->_load_model($model_type);
    my $sql   = $self->_mk_query_update($model, $criteria, $data);
    $criteria = _clean_criteria($model, $criteria);

    eval {
        $model->validate($criteria);
        $model->validate($data);

    }; if ($@) {
        throw $@->message;
    }

    $self->_exec_query($sql, undef, $cb);
}

sub delete {
    my ($self, $model, $data) = @_;

    throw "Not implemented yet";
}

sub create_filter {
    my ($self, $filter) = @_;

    if ( ref($filter) ne 'HASH' ) {
        return '';
    }

    return 'WHERE ' . $self->create_filter_from_hash($filter);
}

sub create_filter_from_hash {
    my ($self, $value, $field, $parent_field) = @_;

    if ( defined( $field ) ) {
        $value = $value->{$field};
    }

    my @fields  = keys( %{ $value } );

    return '' if ( @fields == 0 );

    my @where = ();
    my $connect = 'AND';
    my $conditional = '=';

    # build up the search criteria
    for my $f ( @fields ) {
        my $criteria = '';

        given( $f ) {
            when(/\$eq/) { $conditional = '='; }
            when(/\$ne/) { $conditional = '!='; }
            when(/\$lte/) { $conditional = '<='; }
            when(/\$lt/) { $conditional = '<'; }
            when(/\$gte/) { $conditional = '>='; }
            when(/\$gt/) { $conditional = '>'; }
        }

        if ( ref($value->{$f}) eq 'ARRAY' )
        {
            my $c = $self->create_filter_from_array($value, $f, $field);
            push( @where, $c ) if ( length($c) );
        }
        elsif ( ref($value->{$f}) eq 'HASH' )
        {
            my $c = $self->create_filter_from_hash($value, $f, $field);
            push( @where, $c ) if ( length($c) );
        }
        else {
            my $c = $self->create_filter_from_scalar($value->{$f}, $f, $field, $conditional);
            push( @where, $c ) if ( length($c) );
        }
    }

    return '(' . join(" $connect ", @where) . ')';
}

sub create_filter_from_array {
    my ($self, $value, $field, $parent_field) = @_;

    if ( defined( $field ) ) {
        $value = $value->{$field};
    }

    my @fields = @{ $value };

    return '' if ( @fields == 0 );

    my @where = ();
    my $connect = '';

    given( $field ) {
        when(/\$nor/) { $connect = 'NOT OR'; $field = undef; }
        when(/\$or/)  { $connect = 'OR'; $field = undef; }
        when(/\$and/) { $connect = 'AND'; $field = undef; }
        when(/\$in/)  {
            return '(' . $parent_field . ' IN (' . join(",", @{ $value }) . '))';
        }
        when(/\$nin/) {
            return '(' . $parent_field . ' NOT IN (' . join(",", @{ $value }) . '))';
        }
    }

    # build up the search criteria
    for my $f ( @fields ) {
        my $criteria = '';

        if ( ref($f) eq 'ARRAY' )
        {
            my $c = $self->create_filter_from_array($f, $field);
            push( @where, $c ) if ( length($c) );
        }
        elsif ( ref($f) eq 'HASH' )
        {
            my $c = $self->create_filter_from_hash($f, $field);
            push( @where, $c ) if ( length($c) );
        }
    }

    return '(' . join(" $connect ", @where) . ')';
}

sub create_filter_from_scalar {
    my ($self, $value, $field, $parent_field, $conditional) = @_;

    $conditional //= '=';
    $field = $parent_field if ( $field =~ /^\$/ );

    if ( $value =~ m/[^\d]/ ) {
        return $field . $conditional . "'$value'";
    }

    return $field . $conditional . "'$value'";
}

1;
