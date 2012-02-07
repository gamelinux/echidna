=head1 NAME

AnyEvent::DBI - asynchronous DBI access

=head1 SYNOPSIS

   use AnyEvent::DBI;

   my $cv = AnyEvent->condvar;

   my $dbh = new AnyEvent::DBI "DBI:SQLite:dbname=test.db", "", "";

   $dbh->exec ("select * from test where num=?", 10, sub {
      my ($dbh, $rows, $rv) = @_;

      $#_ or die "failure: $@";

      print "@$_\n"
         for @$rows;

      $cv->broadcast;
   });

   # asynchronously do sth. else here

   $cv->wait;

=head1 DESCRIPTION

This module is an L<AnyEvent> user, you need to make sure that you use and
run a supported event loop.

This module implements asynchronous DBI access by forking or executing
separate "DBI-Server" processes and sending them requests.

It means that you can run DBI requests in parallel to other tasks.

The overhead for very simple statements ("select 0") is somewhere
around 100% to 120% (dual/single core CPU) compared to an explicit
prepare_cached/execute/fetchrow_arrayref/finish combination.

=head2 ERROR HANDLING

This module defines a number of functions that accept a callback
argument. All callbacks used by this module get their AnyEvent::DBI handle
object passed as first argument.

If the request was successful, then there will be more arguments,
otherwise there will only be the C<$dbh> argument and C<$@> contains an
error message.

A convinient way to check whether an error occured is to check C<$#_> -
if that is true, then the function was successful, otherwise there was an
error.

=cut

package AnyEvent::DBI;

use common::sense;

use Carp;
use Socket ();
use Scalar::Util ();
use Storable ();

use DBI (); # only needed in child actually - do it before fork & !exec?

use AnyEvent ();
use AnyEvent::Util ();

use Errno ();
use Fcntl ();
use POSIX ();

our $VERSION = '2.1';

our $FD_MAX = eval { POSIX::sysconf (&POSIX::_SC_OPEN_MAX) - 1 } || 1023;

# this is the forked server code, could/should be bundled as it's own file

our $DBH;

sub req_open {
   my (undef, $dbi, $user, $pass, %attr) = @{+shift};

   $DBH = DBI->connect ($dbi, $user, $pass, \%attr) or die $DBI::errstr;

   [1, 1]
}

sub req_exec {
   my (undef, $st, @args) = @{+shift};
   my $sth = $DBH->prepare_cached ($st, undef, 1)
      or die [$DBI::errstr];

   my $rv = $sth->execute (@args)
      or die [$sth->errstr];

   [1, $sth->{NUM_OF_FIELDS} ? $sth->fetchall_arrayref : undef, $rv]
}

sub req_attr {
   my (undef, $attr_name, @attr_val) = @{+shift};

   $DBH->{$attr_name} = $attr_val[0]
      if @attr_val;

   [1, $DBH->{$attr_name}]
}

sub req_begin_work {
   [1, $DBH->begin_work or die [$DBI::errstr]]
}

sub req_commit {
   [1, $DBH->commit     or die [$DBI::errstr]]
}

sub req_rollback {
   [1, $DBH->rollback   or die [$DBI::errstr]]
}

sub req_func {
   my (undef, $arg_string, $function) = @{+shift};
   my @args = eval $arg_string;

   die "error evaling \$dbh->func() arg_string: $@"
      if $@;

   my $rc = $DBH->func (@args, $function);
   return [1, $rc, $DBI::err, $DBI::errstr];
}

sub serve_fh($$) {
   my ($fh, $version) = @_;

   if ($VERSION != $version) {
      syswrite $fh,
         pack "L/a*",
            Storable::freeze
               [undef, "AnyEvent::DBI version mismatch ($VERSION vs. $version)"];
      return;
   }

   eval {
      my $rbuf;

      while () {
         sysread $fh, $rbuf, 16384, length $rbuf
            or last;

         while () {
            my $len = unpack "L", $rbuf;

            # full request available?
            last unless $len && $len + 4 <= length $rbuf;

            my $req = Storable::thaw substr $rbuf, 4;
            substr $rbuf, 0, $len + 4, ""; # remove length + request

            my $wbuf = eval { pack "L/a*", Storable::freeze $req->[0]($req) };
            $wbuf = pack "L/a*", Storable::freeze [undef, ref $@ ? ("$@->[0]", $@->[1]) : ("$@", 1)]
               if $@;

            for (my $ofs = 0; $ofs < length $wbuf; ) {
               $ofs += (syswrite $fh, substr $wbuf, $ofs
                           or die "unable to write results");
            }
         }
      }
   };
}

sub serve_fd($$) {
   open my $fh, ">>&=$_[0]"
      or die "Couldn't open server file descriptor: $!";

   serve_fh $fh, $_[1];
}

=head2 METHODS

=over 4

=item $dbh = new AnyEvent::DBI $database, $user, $pass, [key => value]...

Returns a database handle for the given database. Each database handle
has an associated server process that executes statements in order. If
you want to run more than one statement in parallel, you need to create
additional database handles.

The advantage of this approach is that transactions work as state is
preserved.

Example:

   $dbh = new AnyEvent::DBI
             "DBI:mysql:test;mysql_read_default_file=/root/.my.cnf", "", "";

Additional key-value pairs can be used to adjust behaviour:

=over 4

=item on_error => $callback->($dbh, $filename, $line, $fatal)

When an error occurs, then this callback will be invoked. On entry, C<$@>
is set to the error message. C<$filename> and C<$line> is where the
original request was submitted.

If the fatal argument is true then the database connection is shut down
and your database handle became invalid. In addition to invoking the
C<on_error> callback, all of your queued request callbacks are called
without only the C<$dbh> argument.

If omitted, then C<die> will be called on any errors, fatal or not.

=item on_connect => $callback->($dbh[, $success])

If you supply an C<on_connect> callback, then this callback will be
invoked after the database connect attempt. If the connection succeeds,
C<$success> is true, otherwise it is missing and C<$@> contains the
C<$DBI::errstr>.

Regardless of whether C<on_connect> is supplied, connect errors will result in
C<on_error> being called. However, if no C<on_connect> callback is supplied, then
connection errors are considered fatal. The client will C<die> and the C<on_error>
callback will be called with C<$fatal> true.

When on_connect is supplied, connect error are not fatal and AnyEvent::DBI
will not C<die>. You still cannot, however, use the $dbh object you
received from C<new> to make requests.

=item exec_server => 1

If you supply an C<exec_server> argument, then the DBI server process will
fork and exec another perl interpreter (using C<$^X>) with just the
AnyEvent::DBI proxy running. This will provide the cleanest possible proxy
for your database server.

If you do not supply the C<exec_server> argument (or supply it with a
false value) then the traditional method of starting the server by forking
the current process is used. The forked interpreter will try to clean
itself up by calling POSIX::close on all file descriptors except STDIN,
STDOUT, and STDERR (and the socket it uses to communicate with the cilent,
of course).

=item timeout => seconds

If you supply a timeout parameter (fractional values are supported), then
a timer is started any time the DBI handle expects a response from the
server. This includes connection setup as well as requests made to the
backend. The timeout spans the duration from the moment the first data
is written (or queued to be written) until all expected responses are
returned, but is postponed for "timeout" seconds each time more data is
returned from the server. If the timer ever goes off then a fatal error is
generated. If you have an C<on_error> handler installed, then it will be
called, otherwise your program will die().

When altering your databases with timeouts it is wise to use
transactions. If you quit due to timeout while performing insert, update
or schema-altering commands you can end up not knowing if the action was
submitted to the database, complicating recovery.

Timeout errors are always fatal.

=back

Any additional key-value pairs will be rolled into a hash reference
and passed as the final argument to the C<< DBI->connect (...) >>
call. For example, to supress errors on STDERR and send them instead to an
AnyEvent::Handle you could do:

   $dbh = new AnyEvent::DBI
              "DBI:mysql:test;mysql_read_default_file=/root/.my.cnf", "", "",
              PrintError => 0,
              on_error   => sub {
                 $log_handle->push_write ("DBI Error: $@ at $_[1]:$_[2]\n");
              };

=cut

# stupid Storable autoloading, total loss-loss situation
Storable::thaw Storable::freeze [];

sub new {
   my ($class, $dbi, $user, $pass, %arg) = @_;

   my ($client, $server) = AnyEvent::Util::portable_socketpair
      or croak "unable to create AnyEvent::DBI communications pipe: $!";

   my %dbi_args = %arg;
   delete @dbi_args{qw(on_connect on_error timeout exec_server)};

   my $self = bless \%arg, $class;
   $self->{fh} = $client;

   AnyEvent::Util::fh_nonblocking $client, 1;

   my $rbuf;
   my @caller = (caller)[1,2]; # the "default" caller

   {
      Scalar::Util::weaken (my $self = $self);

      $self->{rw} = AE::io $client, 0, sub {
         return unless $self;

         $self->{last_activity} = AE::now;

         my $len = sysread $client, $rbuf, 65536, length $rbuf;

         if ($len > 0) {
            # we received data, so reset the timer

            while () {
               my $len = unpack "L", $rbuf;

               # full response available?
               last unless $len && $len + 4 <= length $rbuf;

               my $res = Storable::thaw substr $rbuf, 4;
               substr $rbuf, 0, $len + 4, ""; # remove length + request

               last unless $self;
               my $req = shift @{ $self->{queue} };

               if (defined $res->[0]) {
                  $res->[0] = $self;
                  $req->[0](@$res);
               } else {
                  my $cb = shift @$req;
                  local $@ = $res->[1];
                  $cb->($self);
                  $self->_error ($res->[1], @$req, $res->[2]) # error, request record, is_fatal
                     if $self; # cb() could have deleted it
               }

               # no more queued requests, so become idle
               undef $self->{last_activity}
                  if $self && !@{ $self->{queue} };
            }

         } elsif (defined $len) {
            # todo, caller?
            $self->_error ("unexpected eof", @caller, 1);
         } elsif ($! != Errno::EAGAIN) {
            # todo, caller?
            $self->_error ("read error: $!", @caller, 1);
         }
      };

      $self->{tw_cb} = sub {
         if ($self->{timeout} && $self->{last_activity}) {
            if (AE::now > $self->{last_activity} + $self->{timeout}) {
               # we did time out
               my $req = $self->{queue}[0];
               $self->_error (timeout => $req->[1], $req->[2], 1); # timeouts are always fatal
            } else {
               # we need to re-set the timeout watcher
               $self->{tw} = AE::timer
                  $self->{last_activity} + $self->{timeout} - AE::now,
                  0,
                  $self->{tw_cb},
               ;
            }
         } else {
            # no timeout check wanted, or idle
            undef $self->{tw};
         }
      };

      $self->{ww_cb} = sub {
         return unless $self;

         $self->{last_activity} = AE::now;

         my $len = syswrite $client, $self->{wbuf}
            or return delete $self->{ww};

         substr $self->{wbuf}, 0, $len, "";
      };
   }

   my $pid = fork;

   if ($pid) {
      # parent
      close $server;
   } elsif (defined $pid) {
      # child
      my $serv_fno = fileno $server;

      if ($self->{exec_server}) {
         fcntl $server, &Fcntl::F_SETFD, 0; # don't close the server side
         exec {$^X}
              "$0 dbi slave",
              -e => "require shift; AnyEvent::DBI::serve_fd ($serv_fno, $VERSION)",
              $INC{"AnyEvent/DBI.pm"};
         POSIX::_exit 124;
      } else {
         ($_ != $serv_fno) && POSIX::close $_
            for $^F+1..$FD_MAX;
         serve_fh $server, $VERSION;

         # no other way on the broken windows platform, even this leaks
         # memory and might fail.
         kill 9, $$
            if AnyEvent::WIN32;

         # and this kills the parent process on windows
         POSIX::_exit 0;
      }
   } else {
      croak "fork: $!";
   }

   $self->{child_pid} = $pid;

   $self->_req (
      ($self->{on_connect} ? $self->{on_connect} : sub { }),
      (caller)[1,2],
      req_open => $dbi, $user, $pass, %dbi_args
   );

   $self
}

sub _server_pid {
   shift->{child_pid}
}

sub kill_child {
   my $self = shift;

   if (my $pid = delete $self->{child_pid}) {
      kill TERM => $pid;
   }
   close delete $self->{fh};
}

sub DESTROY {
   shift->kill_child;
}

sub _error {
   my ($self, $error, $filename, $line, $fatal) = @_;

   if ($fatal) {
      delete $self->{tw};
      delete $self->{rw};
      delete $self->{ww};
      delete $self->{fh};

      # for fatal errors call all enqueued callbacks with error
      while (my $req = shift @{$self->{queue}}) {
         local $@ = $error;
         $req->[0]->($self);
      }
      $self->kill_child;
   }

   local $@ = $error;

   if ($self->{on_error}) {
      $self->{on_error}($self, $filename, $line, $fatal)
   } else {
      die "$error at $filename, line $line\n";
   }
}

=item $dbh->on_error ($cb->($dbh, $filename, $line, $fatal))

Sets (or clears, with C<undef>) the C<on_error> handler.

=cut

sub on_error {
   $_[0]{on_error} = $_[1];
}

=item $dbh->timeout ($seconds)

Sets (or clears, with C<undef>) the database timeout. Useful to extend the
timeout when you are about to make a really long query.

=cut

sub timeout {
   my ($self, $timeout) = @_;

   $self->{timeout} = $timeout;

   # reschedule timer if one was running
   $self->{tw_cb}->();
}

sub _req {
   my ($self, $cb, $filename, $line) = splice @_, 0, 4, ();

   unless ($self->{fh}) {
      local $@ = my $err = 'no database connection';
      $cb->($self);
      $self->_error ($err, $filename, $line, 1);
      return;
   }

   push @{ $self->{queue} }, [$cb, $filename, $line];

   # re-start timeout if necessary
   if ($self->{timeout} && !$self->{tw}) {
      $self->{last_activity} = AE::now;
      $self->{tw_cb}->();
   }

   $self->{wbuf} .= pack "L/a*", Storable::freeze \@_;

   unless ($self->{ww}) {
      my $len = syswrite $self->{fh}, $self->{wbuf};
      substr $self->{wbuf}, 0, $len, "";

      # still any left? then install a write watcher
      $self->{ww} = AE::io $self->{fh}, 1, $self->{ww_cb}
         if length $self->{wbuf};
   }
}

=item $dbh->exec ("statement", @args, $cb->($dbh, \@rows, $rv))

Executes the given SQL statement with placeholders replaced by
C<@args>. The statement will be prepared and cached on the server side, so
using placeholders is extremely important.

The callback will be called with a weakened AnyEvent::DBI object as the
first argument and the result of C<fetchall_arrayref> as (or C<undef>
if the statement wasn't a select statement) as the second argument.

Third argument is the return value from the C<< DBI->execute >> method
call.

If an error occurs and the C<on_error> callback returns, then only C<$dbh>
will be passed and C<$@> contains the error message.

=item $dbh->attr ($attr_name[, $attr_value], $cb->($dbh, $new_value))

An accessor for the handle attributes, such as C<AutoCommit>,
C<RaiseError>, C<PrintError> and so on. If you provide an C<$attr_value>
(which might be C<undef>), then the given attribute will be set to that
value.

The callback will be passed the database handle and the attribute's value
if successful.

If an error occurs and the C<on_error> callback returns, then only C<$dbh>
will be passed and C<$@> contains the error message.

=item $dbh->begin_work ($cb->($dbh[, $rc]))

=item $dbh->commit     ($cb->($dbh[, $rc]))

=item $dbh->rollback   ($cb->($dbh[, $rc]))

The begin_work, commit, and rollback methods expose the equivalent
transaction control method of the DBI driver. On success, C<$rc> is true.

If an error occurs and the C<on_error> callback returns, then only C<$dbh>
will be passed and C<$@> contains the error message.

=item $dbh->func ('string_which_yields_args_when_evaled', $func_name, $cb->($dbh, $rc, $dbi_err, $dbi_errstr))

This gives access to database driver private methods. Because they
are not standard you cannot always depend on the value of C<$rc> or
C<$dbi_err>. Check the documentation for your specific driver/function
combination to see what it returns.

Note that the first argument will be eval'ed to produce the argument list to
the func() method. This must be done because the serialization protocol
between the AnyEvent::DBI server process and your program does not support the
passage of closures.

Here's an example to extend the query language in SQLite so it supports an
intstr() function:

    $cv = AnyEvent->condvar;
    $dbh->func (
       q{
          instr => 2, sub {
             my ($string, $search) = @_;
             return index $string, $search;
          },
       },
       create_function => sub {
          return $cv->send ($@)
             unless $#_;
          $cv->send (undef, @_[1,2,3]);
       }
    );

    my ($err,$rc,$errcode,$errstr) = $cv->recv;

    die $err if defined $err;
    die "EVAL failed: $errstr"
       if $errcode;

    # otherwise, we can ignore $rc and $errcode for this particular func

=cut

for my $cmd_name (qw(exec attr begin_work commit rollback func)) {
   eval 'sub ' . $cmd_name . '{
      my $cb = pop;
      splice @_, 1, 0, $cb, (caller)[1,2], "req_' . $cmd_name . '";
      &_req
   }';
}

=back

=head1 SEE ALSO

L<AnyEvent>, L<DBI>, L<Coro::Mysql>.

=head1 AUTHOR

   Marc Lehmann <schmorp@schmorp.de>
   http://home.schmorp.de/

   Adam Rosenstein <adam@redcondor.com>
   http://www.redcondor.com/

=cut

1;

