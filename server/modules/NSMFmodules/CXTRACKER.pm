package NSMFmodules::CXTRACKER;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use DateTime;
use DBI;
use DBD::mysql;
use Carp::Heavy;
#use NSMFcommon::IP;
require Exporter;
@EXPORT = qw(CXTRACKER);
$VERSION = '0.1';

# Default config
my $DB_USERNAME = q(nsmf);
my $DB_PASSWORD = q(nsmf);
my $DB_NAME = q(nsmf);
my $DB_HOST = q(127.0.0.1);
my $DB_PORT = q(3306);

# Load config file, and overwrite defaults

# Globals for this module
our $NODENAME = q(default);
our $DEBUG = 1;
our $DBI = "DBI:mysql:$DB_NAME:$DB_HOST:$DB_PORT";
our $dbh = undef;

=head2 CXTRACKER

 This is the module that the nsmf-server calls when it passes
 a $REQ (request) to this module. This is the only module that
 we export and is used by nsmf.

=cut

sub CXTRACKER {
    my $REQ = shift;
    $DEBUG = $REQ->{'debug'};
    $NODENAME = $REQ->{'node'};
    print "[**] CXTRACKER: Huston - we got a request for $NODENAME.\n" if $DEBUG;
    print "OK\n" if not (NSMFmodules::CXTRACKER::put_cxdata_to_db($REQ));
    undef $REQ;
    return;
}

=head2 import

 When perl loads a perl-module, the sub import gets executed.
 We take advantage of this to initialize the database connection
 and set up the DB.

=cut

sub import {
    # automatic happens when its imported
    print "[**] CXTRACKER: Connecting to database...\n";
    $dbh = DBI->connect($DBI,$DB_USERNAME,$DB_PASSWORD, {RaiseError => 1}) or die "$DBI::errstr";
    print "[**] CXTRACKER: Connection OK...\n";
    # Make todays table, and initialize the session merged table
    setup_db();
}

sub DESTROY {
    print "CXTRACKER: Dead on arrival!\n";
}

=head2 put_cxdata_to_db

 This module processes the data from the cxtracker node
 and inserts it to the nsmf-server database via put_session2db.

=cut

sub put_cxdata_to_db {
    my $REQ = shift;
    my $result = 1;
    print "put_cxdata_to_db\n";
    LINE:
    while (my @lines = split /\n/, $REQ->{'data'}) {
        foreach my $line (@lines) {
            chomp $line;
            $line =~ /^\d{19}/;
            unless($line) {
                print "[*] Error: Not valid session start format in: '$line'";
                next LINE;
            }
            my @elements = split /\|/,$line;
            unless(@elements == 15) {
                print "[*] Error: Not valid Nr. of session args format in: '$line'";
                next LINE;
            }
            # Things should be OK now to send to the DB
            print "$line\n";
            $result = put_session2db($line);
        }
    }
    return $result;
}

=head2 checkif_table_exist

 Checks if a table exists. Takes $tablename as input and
 returns 1 if $tablename exists, and 0 if not.

=cut

sub checkif_table_exist {
    my $tablename = shift;
    my ($sql, $sth);
    eval {
       $sql = "select count(*) from $tablename where 1=0";
       $dbh->do($sql);
    };
    if ($dbh->err) {
       warn "Table $tablename does not exist.\n" if $DEBUG;
       return 0;
    }
    else{
       return 1;
    }
}

sub put_session2db {
   my $SESSION = shift;
   my $tablename = get_table_name();
   my $ip_version = 2; # AF_INET

   # Check if table exists, if not create and make new session merge table
   if ( ! checkif_table_exist($tablename) ) {
      new_session_table($tablename);
      recreate_merge_table();
   }

   my( $cx_id, $s_t, $e_t, $tot_time, $ip_type, $src_dip, $src_port,
       $dst_dip, $dst_port, $src_packets, $src_byte, $dst_packets, $dst_byte,
       $src_flags, $dst_flags) = split /\|/, $SESSION, 15;

  if ( ip_is_ipv6($src_dip) || ip_is_ipv6($dst_dip) ) {
      $src_dip = expand_ipv6($src_dip);
      $dst_dip = expand_ipv6($dst_dip);
      $src_dip = "INET_ATON6(\'$src_dip\')";
      $dst_dip = "INET_ATON6(\'$dst_dip\')";
      $ip_version = 10; # AF_INET6
  }

   my ($sql, $sth);
   eval{

      $sql = qq[
             INSERT INTO $tablename (
                sid,sessionid,start_time,end_time,duration,ip_proto,
                src_ip,src_port,dst_ip,dst_port,src_pkts,src_bytes,
                dst_pkts,dst_bytes,src_flags,dst_flags,ip_version
             ) VALUES (
                '$NODENAME','$cx_id','$s_t','$e_t','$tot_time',
                '$ip_type',$src_dip,'$src_port',$dst_dip,'$dst_port',
                '$src_packets','$src_byte','$dst_packets','$dst_byte',
                '$src_flags','$dst_flags','$ip_version'
             )];

      $sth = $dbh->prepare($sql);
      $sth->execute;
      $sth->finish;
   };
   if ($@) {
      # Failed
      return 1;
   }
   return 0;
}

sub setup_db {
    #my $dbh = shift;
    my $tablename = get_table_name();
    new_session_table($tablename);
    delete_merged_session_table();
    my $sessiontables = find_session_tables();
    merge_session_tables($sessiontables);
    return;
}

=head2 merge_session_tables

 Creates a new session merge table

=cut

sub merge_session_tables {
   my $tables = shift;
   my ($sql, $sth);
   eval {
      # check for != MRG_MyISAM - exit
      warn "[*] Creating session MERGE table\n" if $DEBUG;
      my $sql = "                                        \
      CREATE TABLE session                               \
      (                                                  \
      sid           INT(0) UNSIGNED            NOT NULL, \
      sessionid       BIGINT(20) UNSIGNED      NOT NULL, \
      start_time    DATETIME                   NOT NULL, \
      end_time      DATETIME                   NOT NULL, \
      duration      INT(10) UNSIGNED           NOT NULL, \
      ip_proto      TINYINT(3) UNSIGNED        NOT NULL, \
      ip_version    TINYINT(3) UNSIGNED        NOT NULL, \
      src_ip        DECIMAL(39,0) UNSIGNED,              \
      src_port      SMALLINT UNSIGNED,                   \
      dst_ip        DECIMAL(39,0) UNSIGNED,              \
      dst_port      SMALLINT UNSIGNED,                   \
      src_pkts      INT UNSIGNED               NOT NULL, \
      src_bytes     INT UNSIGNED               NOT NULL, \
      dst_pkts      INT UNSIGNED               NOT NULL, \
      dst_bytes     INT UNSIGNED               NOT NULL, \
      src_flags     TINYINT UNSIGNED           NOT NULL, \
      dst_flags     TINYINT UNSIGNED           NOT NULL, \
      INDEX p_key (sid,sessionid),                       \
      INDEX src_ip (src_ip),                             \
      INDEX dst_ip (dst_ip),                             \
      INDEX dst_port (dst_port),                         \
      INDEX src_port (src_port),                         \
      INDEX start_time (start_time)                      \
      ) TYPE=MERGE UNION=($tables)                       \
      ";
      $sth = $dbh->prepare($sql);
      $sth->execute;
      $sth->finish;
   };
   if ($@) {
      # Failed
      warn "[*] Create session MERGE table failed!\n" if $DEBUG;
      return 1;
   }
   return 0;
}

=head2 get_table_name

 makes a table name, format: session_$NODENAME_$DATE

=cut

sub get_table_name {
    my $DATE = `date --iso`;
    $DATE =~ s/\-//g;
    $DATE =~ s/\n$//;
    my $tablename = "cxtracker_" . "$NODENAME" . "_" . "$DATE";
    return $tablename;
}

=head2 new_session_table

 Creates a new session_$hostname_$date table
 Takes $hostname and $date as input.

=cut

sub new_session_table {
   my $tablename = shift;
   my ($sql, $sth);
   eval{
      $sql = "                                             \
        CREATE TABLE IF NOT EXISTS $tablename              \
        (                                                  \
        sid           INT(10) UNSIGNED           NOT NULL, \
        sessionid     BIGINT(20) UNSIGNED        NOT NULL, \
        start_time    DATETIME                   NOT NULL, \
        end_time      DATETIME                   NOT NULL, \
        duration      INT(10) UNSIGNED           NOT NULL, \
        ip_proto      TINYINT UNSIGNED           NOT NULL, \
        ip_version    TINYINT UNSIGNED           NOT NULL, \
        src_ip        DECIMAL(39,0) UNSIGNED,              \
        src_port      SMALLINT UNSIGNED,                   \
        dst_ip        DECIMAL(39,0) UNSIGNED,              \
        dst_port      SMALLINT UNSIGNED,                   \
        src_pkts      INT UNSIGNED               NOT NULL, \
        src_bytes     INT UNSIGNED               NOT NULL, \
        dst_pkts      INT UNSIGNED               NOT NULL, \
        dst_bytes     INT UNSIGNED               NOT NULL, \
        src_flags     TINYINT UNSIGNED           NOT NULL, \
        dst_flags     TINYINT UNSIGNED           NOT NULL, \
        PRIMARY KEY (sid,sessionid),                       \
        INDEX src_ip (src_ip),                             \
        INDEX dst_ip (dst_ip),                             \
        INDEX dst_port (dst_port),                         \
        INDEX src_port (src_port),                         \
        INDEX start_time (start_time)                      \
        )                                                  \
      ";
      $sth = $dbh->prepare($sql);
      $sth->execute;
      $sth->finish;
   };
   if ($@) {
      # Failed
      return 1;
   }
   return 0;
}

=head2 delete_merged_session_table

 Deletes the session merged table if it exists.

=cut

sub delete_merged_session_table {
    my ($sql, $sth);
    eval{
        $sql = "DROP TABLE IF EXISTS session";
        $sth = $dbh->prepare($sql);
        $sth->execute;
        $sth->finish;
    };
    if ($@) {
        # Failed
        warn "[*] Drop merge-table cxtracker failed...\n" if $DEBUG;
        return 1;
    }
    warn "[*] Dropped merge-table cxtracker...\n" if $DEBUG;
    return 0;
}

=head2 find_session_tables
 
 Find all session_% tables

=cut

sub find_session_tables {
    my ($sql, $sth);
    my $tables = q();
    $sql = q(SHOW TABLES LIKE 'session_%');
    $sth = $dbh->prepare($sql);
    $sth->execute;
    while (my @array = $sth->fetchrow_array) {
        my $table = $array[0];
        $tables = "$tables $table,";
    }
    $sth->finish;
    $tables =~ s/,$//;
    return $tables;;
}

=head2 recreate_merge_table

 Recreates the merge table.

=cut

sub recreate_merge_table {
   my $sessiontables = find_session_tables();
   delete_merged_session_table();
   merge_session_tables($sessiontables);
}


END {
    #my $dbh = q(); # fake fake fake : FIXME
    # Stuff to do when we die
    warn "[*] Terminating module CXTRACKER...\n";
    $dbh->disconnect;
    exit 0;
}

1;
