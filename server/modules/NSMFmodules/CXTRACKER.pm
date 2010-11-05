package NSMFmodules::CXTRACKER;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);
use DateTime;
use DBI;
require Exporter;
@EXPORT = qw(CXTRACKER);
$VERSION = '0.1';

our 

sub CXTRACKER {
    my $REQ = shift;
    print "[*] Huston - we got packet! Best regards, your CXTRACKER module!\n" if $REQ->{'debug'};
    put_cxdata_to_db($REQ);
    undef $REQ;
    return;
}

sub import {
    # automatic happens when its imported
    warn "[*] Connecting to database...\n";
    my $dbh = DBI->connect($DBI,$DB_USERNAME,$DB_PASSWORD, {RaiseError => 1}) or die "$DBI::errstr";
    # Make todays table, and initialize the session merged table
    setup_db($dbh);
}

sub DESTROY {
    print "Dead on arrival!\n";
}

=head2 put_cxdata_to_db

 This module processes the data from the cxtracker node
 and inserts it to the nsmf-server database via put_session2db.

=cut

sub put_cxdata_to_db {
    my $REQ = shift;
    my $DEBUG = $REQ->{'debug'};
    LINE:
    while (my $line = readlien $REQ->{'data'}) {
        #while (my $line = readline FILE) {
        chomp $line;
        $line =~ /^\d{19}/;
        unless($line) {
            print "[*] Error: Not valid session start format in: '$SFILE'";
            next LINE;
        }
        my @elements = split/\|/,$line;
        unless(@elements == 15) {
            print "[*] Error: Not valid Nr. of session args format in: '$SFILE'";
            next LINE;
        }
        # Things should be OK now to send to the DB
        $result = put_session2db($line);
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
                '$HOSTNAME','$cx_id','$s_t','$e_t','$tot_time',
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
    my $dbh = shift;
    #my $tablename = get_table_name();
    #new_session_table($dbh, $tablename);
    delete_merged_session_table($dbh);
    my $sessiontables = find_session_tables($dbh);
    merge_session_tables($dbh, $sessiontables);
    return;
}

=head2 get_table_name

 makes a table name, format: session_$HOSTNAME_$DATE

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
   my ($dbh, $tablename) = shift;
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
    my $dbh = shift;
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
    my $dbh = shift;
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
    # Stuff to do when we die
    warn "[*] Terminating module CXTRACKER...\n";
    $dbh->disconnect;
    exit 0;
}

1;
