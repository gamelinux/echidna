#!/usr/bin/perl

use Socket;
#use NetPacket;
use NetPacket::Ethernet;
use NetPacket::IP;
use NetPacket::TCP;
use NetPacket::UDP;
use NetPacket::ICMP;
use warnings;
use strict;

use constant ETHERNET_TYPE_IP    => 0x0800;

use constant IP_PROTO_TCP  => 6;
use constant IP_PROTO_ICMP => 1;
use constant IP_PROTO_UDP  => 17;
use constant IP_PROTO_IPIP => 4;
use constant IP_PROTO_IGMP => 2;

use constant FIN => 0x01;
use constant SYN => 0x02;
use constant RST => 0x04;
use constant PSH => 0x08;
use constant ACK => 0x10;
use constant URG => 0x20;
use constant ECE => 0x40;
use constant CWR => 0x80;


our $PKT_RB_FLAG   = 0x00000002;
our $PKT_DF_FLAG   = 0x00000004;
our $PKT_MF_FLAG   = 0x00000008;

my $HANDLERS = {};
my $QUALIFIERS = {};
our $UF = {
        'FILENAME' => '',
        'TYPE' => '',
        'MAGIC' => '',
        'VERSION_MAJOR' => '',
        'VERSION_MINOR' => '',
        'TIMEZONE' => '',
        'SIG_FLAG' => '',
        'SNAPLEN' => '',
        'LINKTYPE' => '',
        'PACKSTR' => '',
        'FIELDS' => '',
        'RECORDSIZE' => 0,
        'FILESIZE' => 0,
        'FILEMTIME' => 0,
        'FILEPOS' => 0,
        'PATIENCE' => 1,
        'TOLERANCE' => 0,
        'LOCKED' => 0,
        '64BIT' => 0,
};

our $UF_Data = {};
our $UF_Record = {};
our $debug = 0;
our $flock_mode = 0;
our $record = {};
our $sids;
our $class;

our $LOGMAGIC = 0xdead1080;
our $ALERTMAGIC = 0xdead4137;
my $LOGMAGICV = 0xdead1080;
my $LOGMAGICN = 0x8010adde;;
my $ALERTMAGICV = 0xdead4137;
my $ALERTMAGICN = 0x3741adde;

our $UNIFIED_LOG   = "LOG";
our $UNIFIED_ALERT = "ALERT";
our $UNIFIED2      = "UNIFIED2";

my $unified2_ids_fields = [
        'sensor_id',
        'event_id',
        'tv_sec',
        'tv_usec',
        'sig_id',
        'sig_gen',
        'sig_rev',
        'class',
        'pri',
        'sip',
        'dip',
        'sp',
        'dp',
        'protocol',
        'pkt_action'
];
my $unified2_packet_fields = [
        'sensor_id',
        'event_id',
        'tv_sec',
        'pkt_sec',
        'pkt_usec',
        'linktype',
        'pkt_len',
        'pkt'
];
my $alert32_fields = [
        'sig_gen',
        'sig_id',
        'sig_rev',
        'class',
        'pri',
        'event_id',
        'reference',
        'tv_sec',
        'tv_usec',
        'tv_sec2',
        'tv_usec2',
        'sip',
        'dip',
        'sp',
        'dp',
        'protocol',
        'flags'
];
my $alert64_fields = [
        'sig_gen',
        'sig_id',
        'sig_rev',
        'class',
        'pri',
        'event_id',
        'reference',
        'p1',
        'tv_sec',
        'p1a',
        'tv_usec',
        'p1b',
        'p2',
        'tv_sec2',
        'p2a',
        'tv_usec2',
        'p2b',
        'sip',
        'dip',
        'sp',
        'dp',
        'protocol',
        'flags'
];
my $log32_fields = [
        'sig_gen',
        'sig_id',
        'sig_rev',
        'class',
        'pri',
        'event_id',
        'reference',
        'tv_sec',
        'tv_usec',
        'flags',
        'pkt_sec',
        'pkt_usec',
        'caplen',
        'pktlen',
        'pkt',
];

my $log64_fields = [
        'sig_gen',
        'sig_id',
        'sig_rev',
        'class',
        'pri',
        'event_id',
        'reference',
        'p1',
        'tv_sec',
        'p1a',
        'tv_usec',
        'p1b',
        'flags',
        'p2',
        'pkt_sec',
        'p2a',
        'pkt_usec',
        'p2b',
        'caplen',
        'pktlen',
        'pkt',
];
our $alert_fields = $alert32_fields;
our $log_fields = $log32_fields;
our $alert2_fields = $unified2_ids_fields;
our $log2_fields = $unified2_packet_fields;


our $UNIFIED2_EVENT          = 1;
our $UNIFIED2_PACKET         = 2;
our $UNIFIED2_IDS_EVENT      = 7;
our $UNIFIED2_EVENT_EXTENDED = 66;
our $UNIFIED2_PERFORMANCE    = 67;
our $UNIFIED2_PORTSCAN       = 68;
our $UNIFIED2_IDS_EVENT_IPV6 = 72;


our $IP_PROTO_NAMES = {
    4 => 'IP',
    1 => 'ICMP',
    2 => 'IGMP',
    94 => 'IPIP',
    6 => 'TCP',
    17 => 'UDP',,
};

our $ICMP_TYPES = {
    0 => 'Echo Reply',
    3 => 'Unreachable',
    4 => 'Source Quench',
    5 => 'Redirect',
    8 => 'Echo',
    9 => 'Router Advertisement',
    10 => 'Router Solicit',
    11 => 'Time Exceeded',
    12 => 'Parameter Problem',
    13 => 'Timestamp',
    14 => 'Timestamp Reply',
    15 => 'Information Request',
    16 => 'Information Reply',
    17 => 'Mask Request',
    18 => 'Mask Reply',
};

my $unified2_type_masks = {
        $UNIFIED2_EVENT          => 'N11n2c2',
        # XXX - Need to verify this struct
        # $UNIFIED2_PACKET         => 'N7c*',
        $UNIFIED2_PACKET         => 'N7',
        # XXX - Need to verify this struct
        $UNIFIED2_IDS_EVENT      => 'N11n2c2',
        # XXX - Need to track down these structs
        $UNIFIED2_EVENT_EXTENDED => '',
        $UNIFIED2_PERFORMANCE    => '',
        $UNIFIED2_PORTSCAN       => '',
        # XXX - Need to track down real size of in6_addr ( using N3N3 right now )
        $UNIFIED2_IDS_EVENT_IPV6 => 'N9N3N3n2c2',
};


our $UNIFIED2_TYPES = {
        $UNIFIED2_EVENT             => 'EVENT',
        $UNIFIED2_PACKET            => 'PACKET',
        $UNIFIED2_IDS_EVENT         => 'IPS4 EVENT',
        $UNIFIED2_EVENT_EXTENDED    => 'EXTENDED',
        $UNIFIED2_PERFORMANCE       => 'PERFORMANCE',
        $UNIFIED2_PORTSCAN          => 'PORTSCAN',
        $UNIFIED2_IDS_EVENT_IPV6    => 'IPS6 EVENT',
};

sub register_handler($$) {
    my $hdlr = shift;
    my $sub = shift;
    chomp $hdlr;
    debug("Registering a handler for " . $hdlr);
    push(@{$HANDLERS->{$hdlr}}, $sub);
}


register_handler('unified2_record', \&printrec);
register_handler('unified2_packet', \&make_ascii_pkt);

sub printrec() {
  my $rec = shift;

  my $i = 0;
  # print $UNIFIED2_TYPES->{$rec->{'TYPE'}};
  foreach my $field ( @{$rec->{'FIELDS'}} ) {
    # if ( $field ne 'pkt' ) {
      print($rec->{$field} . ",");
    # }
  }
  print($i++ . "\n");

  return 1;

}

sub make_ascii_pkt() {
    my $rec = shift;
    my $asc = unpack('a*', $rec->{'pkt'});
    $asc =~ tr/A-Za-z0-9;:\"\'.,<>[]\\|?\/\`~!\@#$%^&*()_\-+={}/./c;
    $rec->{'pkt'} = $asc;
}

sub get_snort_sids($$) {
    my $sidfile = $_[0];
    my $genfile = $_[1];
    my @sid;
    my $sids;
    my @generator;

    return undef unless open(FD, "<", $sidfile);
    while (<FD>) {
        s/#.*//;
        next if /^(\s)*$/;
        chomp;
        #@sid = split(/\s\|\|\s/);
        my ($id, $msg, @ref) = split / +\|\| +/;
        #$sids->{1}->{$sid}->{'msg'} = $sid[1];
        $sids->{1}->{$id}->{'msg'} = $msg;
        $sids->{1}->{$id}->{'reference'} = @ref;
        #$sids->{1}->{$sid[0]}->{'reference'} = $sid[2..$#sid];
    }
    close(FD);

    return $sids unless open(FD, "<", $genfile);
    while (<FD>) {
        s/#.*//;
        next if /^(\s)*$/;
        chomp;
        @generator = split(/\s\|\|\s/);
        $sids->{$generator[0]}->{$generator[1]}->{'msg'} = $generator[2];
    }
    return $sids;
}

sub get_snort_classifications ($) {
    my $file = $_[0];
    my @classification;
    my $class;
    my $classid = 1;

    return undef unless open(FD, "<", $file);
    while (<FD>) {
        s/#.*//;
        s/: /:/;
        next if /^(\s)*$/;
        chomp;
        @classification = split(/:/);
        @classification = split(/,/,$classification[1]);
        $class->{$classid}->{'type'} = $classification[0];
        $class->{$classid}->{'name'} = $classification[1];
        $class->{$classid}->{'priority'} = $classification[2];
        $classid++;
    }
    close(FD);

    return $class;
}


sub openSnortUnified($) {
   $UF->{'FILENAME'} = $_[0];
   $UF->{'TYPE'} = '';
   $UF->{'PACKSTR'} = '';
   $UF->{'FIELDS'} = '';
   $UF->{'RECORDSIZE'} = 0;
   $UF->{'FILESIZE'} = 0;
   $UF->{'FILEMTIME'} = 0;
   $UF->{'FILEPOS'} = 0;


   my $magic = 0;
   if ( !open(UFD, "<", $UF->{'FILENAME'})) {
     print("Cannot open file $UF->{'FILENAME'}\n");
     $UF = undef;
     return $UF;
   }

   binmode(UFD);
   # See if we can get an exclusive lock
   # The presumption being that if we can get an exclusive
   # then the file is not actively being written to
   # JRB - This turns out to not be true :(
   # Only real alternative option is to keep reading the file
   # and occasionally check for a newer file to process
#   if ( $flock_mode ) {
#       if ( flock(UFD, LOCK_EX & LOCK_NB) ) {
#           debug("Got an exclusive lock\n");
#           $UF->{'LOCKED'} = 1;
#       } else {
#           $UF->{'LOCKED'} = 0;
#           debug("Did not get an exclusive lock\n");
#       }
#   }

   (undef,undef,undef,undef,undef,undef,undef,$UF->{'FILESIZE'},undef,$UF->{'FILEMTIME'},undef,undef,undef) = stat(UFD);
   $UF->{'FILESIZE'} = (stat(UFD))[7];
   $UF->{'FILEMTIME'} = (stat(UFD))[9];

   read(UFD, $magic, 4);
   $magic = unpack('V', $magic);

  if ( $UF->{'64BIT'} ) {
     debug("Handling unified file with 64bit timevals");
     $log_fields = $log64_fields;
     $alert_fields = $alert64_fields;
     if ( $magic eq $LOGMAGICV ) {
       $UF->{'TYPE'} = $UNIFIED_LOG;
       $UF->{'FIELDS'} = $log_fields;
       $UF->{'RECORDSIZE'} = 20 * 4;
       $UF->{'PACKSTR'} = 'V20';

     } elsif ( $magic eq $LOGMAGICN ) {
       $UF->{'TYPE'} = $UNIFIED_LOG;
       $UF->{'FIELDS'} = $log_fields;
       $UF->{'RECORDSIZE'} = 20 * 4;
       $UF->{'PACKSTR'} = 'N20';

     } elsif ( $magic eq $ALERTMAGICV ) {
       $UF->{'TYPE'} = $UNIFIED_ALERT;
       $UF->{'FIELDS'} = $alert_fields;
       $UF->{'RECORDSIZE'} = (21 * 4) + (2 * 2);
       $UF->{'PACKSTR'} = 'V19v2V2';

     } elsif ( $magic eq $ALERTMAGICN ) {
       $UF->{'TYPE'} = $UNIFIED_ALERT;
       $UF->{'FIELDS'} = $alert_fields;
       $UF->{'RECORDSIZE'} = (21 * 4) + (2 * 2);
       $UF->{'PACKSTR'} = 'N19n2N2';

     } else {
       # no magic, go back to beginning
       seek(UFD,0,0);
       $UF->{'TYPE'} = $UNIFIED2;
       # The rest doesn't really matter because it changes from record to record
       debug("No match on magic, assuming unified2");
       # die("XXX - Finish unified2 handling");
     }
  } else { # assume 32bit
     debug("Handling unified file with 32bit timevals");
     $log_fields = $log32_fields;
     $alert_fields = $alert32_fields;
     if ( $magic eq $LOGMAGICV ) {
       $UF->{'TYPE'} = 'LOG';
       $UF->{'FIELDS'} = $log_fields;
       $UF->{'RECORDSIZE'} = 14 * 4;
       $UF->{'PACKSTR'} = 'V14';

     } elsif ( $magic eq $LOGMAGICN ) {
       $UF->{'TYPE'} = 'LOG';
       $UF->{'FIELDS'} = $log_fields;
       $UF->{'RECORDSIZE'} = 14 * 4;
       $UF->{'PACKSTR'} = 'N14';

     } elsif ( $magic eq $ALERTMAGICV ) {
       $UF->{'TYPE'} = 'ALERT';
       $UF->{'FIELDS'} = $alert_fields;
       $UF->{'RECORDSIZE'} = (15 * 4) + (2 * 2);
       $UF->{'PACKSTR'} = 'V13v2V2';

     } elsif ( $magic eq $ALERTMAGICN ) {
       $UF->{'TYPE'} = 'ALERT';
       $UF->{'FIELDS'} = $alert_fields;
       $UF->{'RECORDSIZE'} = (15 * 4) + (2 * 2);
       $UF->{'PACKSTR'} = 'N13n2N2';

     } else {
       # no magic, go back to beginning
       seek(UFD,0,0);
       $UF->{'TYPE'} = $UNIFIED2;
       # Note the new fields
       $log_fields = $unified2_packet_fields;
       $alert_fields = $unified2_ids_fields;
       # The rest doesn't really matter because it changes from record to record
       debug("No match on magic, assuming unified2");
       # die("XXX - Finish unified2 handling");
     }
  }

  exec_handler("unified_opened", $UF);

  readSnortUnifiedHeader($UF);

  return $UF;
}


sub readSnortUnifiedHeader($) {
    my $h = $_[0];
    my $buff;
    my $header = 0;

    # Reset at beginning of file
    seek(UFD,0,0);

    if ( $h->{'TYPE'} eq $UNIFIED_LOG ) {
        $header += read(UFD, $buff, 4);
        $h->{'MAGIC'} = unpack($h->{'4'}, $buff);
        $header += read(UFD, $buff, 2);
        $h->{'VERSION_MAJOR'} = unpack($h->{'2'}, $buff);
        $header += read(UFD, $buff, 2);
        $h->{'VERSION_MINOR'} = unpack($h->{'2'}, $buff);
        $header += read(UFD, $buff, 4);
        $h->{'TIMEZONE'} = unpack($h->{'4'}, $buff);
        $header += read(UFD, $buff, 4);
        $h->{'SIG_FLAG'} = unpack($h->{'4'}, $buff);
        $header += read(UFD, $buff, 4);
        $h->{'SLAPLEN'} = unpack($h->{'4'}, $buff);
        $header += read(UFD, $buff, 4);
        $h->{'LINKTYPE'} = unpack($h->{'4'}, $buff);
    } elsif ($h->{'TYPE'} eq $UNIFIED_ALERT) {
        $header += read(UFD, $buff, 4);
        $h->{'MAGIC'} = unpack($h->{'4'}, $buff);
        $header += read(UFD, $buff, 4);
        $h->{'VERSION_MAJOR'} = unpack($h->{'4'}, $buff);
        $header += read(UFD, $buff, 4);
        $h->{'VERSION_MINOR'} = unpack($h->{'4'}, $buff);
        $header += read(UFD, $buff, 4);
        $h->{'TIMEZONE'} = unpack($h->{'4'}, $buff);
    } elsif ( $h->{'TYPE'} eq $UNIFIED2 ) {
        debug("Nothing to handle for unified2");
    } else {
        # XXX - Fallthrough 
        debug("Fallthrough in readSnortUNifiedHeader");
    }
    $UF->{'FILEPOS'} = $header;

    exec_handler("read_header", $h);

}

sub debug($) {
    return unless $debug;
    my $msg = $_[0];
        my $package = undef;
        my $filename = undef;
        my $line = undef;
        ($package, $filename, $line) = caller();
    print STDERR $filename . ":" . $line . " : " . $msg . "\n";
}

sub exec_handler($$) {
    my $hdlr = shift;
    my $data = shift;
    chomp $hdlr;
    debug("Checking handler " . $hdlr);
    if ( defined $HANDLERS->{$hdlr} ) {
        debug("Executing handlers " . $hdlr);
        foreach my $sub (@{$HANDLERS->{$hdlr}}) {
            debug("Executing handlers " . $sub);
            eval { &$sub($data); }
        }
    } else {
        debug("No registered handler for " . $hdlr);
    }
}

sub readData($$) {
    my $size = $_[0];
    my $tolerance = $_[1];

    my $buffer = undef;
    my $readsize = 0;
    my $deads = 0;
    my $fsize = 0;
    my $mtime = 0;


    $readsize = read(UFD, $buffer, $size, $readsize);
    while ( $readsize != $size ) {
        # reset EOF condition if it exists
        seek(UFD, $UF->{'FILEPOS'}+$readsize, 0);
        $readsize += read(UFD, $buffer, $size-$readsize, $readsize);
        $fsize = (stat(UFD))[7];
        $mtime = (stat(UFD))[9];

        debug("Read $readsize bytes so far in readData.");
        debug("fpos is $fsize:$UF->{'FILEPOS'} in readData.");
        debug("mtime is $mtime:$UF->{'FILEMTIME'} in readData.");

        # if the file is unchanged track dead reads
        if ( ( $mtime eq $UF->{'FILEMTIME'} ) &&
             ( $fsize eq $UF->{'FILESIZE'} ) &&
             ( $fsize eq $UF->{'FILEPOS'} )) {
            $deads++;
            if ( $tolerance == 0 || $deads % $tolerance == 0 ) {
                debug("Bailing on deads of $deads in readData");
                debug("Seeking to $UF->{'FILEPOS'}");
                seek(UFD, $UF->{'FILEPOS'}, 0);
                return (-1,undef);
            }
            $UF->{'FILEMTIME'} = $mtime;
            $UF->{'FILESIZE'} = $fsize;
        }
        sleep $UF->{'PATIENCE'};
    }
    $UF->{'FILEPOS'} += $readsize;
    $UF->{'FILESIZE'} = $fsize;
    $UF->{'FILEMTIME'} = $mtime;
    #Expose the raw data
    $UF_Record->{'raw_record'} = $buffer;

    # This is strange - edited by Edward
    #exec_handler("read_data", ($readsize, $buffer));
    exec_handler("read_data", $UF_Record);

    return ($readsize, $buffer);
}

sub exec_qualifier($$$$) {
    my $type = shift;
    my $gen = shift;
    my $sid = shift;
    my $rec = shift;
    my $retval = 1;
    my $pcreretval = 1;
    my $ret_eval = 0;

    if ( defined $QUALIFIERS->{0}->{0}->{0} ) {
        debug("Executing qualifier for 0 0 0");
        foreach my $block (@{$QUALIFIERS->{0}->{0}->{0}}) {
            last if ( $retval < 1 );
            debug("Executing qualifier " . $block);
            eval { $ret_eval = &$block($rec); };
            $retval = $retval & $ret_eval;
        }
    }

    if ( defined $QUALIFIERS->{0}->{$gen}->{$sid} ) {
        # A decision was made to operate on this GEN:SID, reset retval.
        $retval = 1;
        debug("Executing qualifier for 0 :" . $gen . ":" . $sid);
        foreach my $block (@{$QUALIFIERS->{0}->{$gen}->{$sid}}) {
            last if ( $retval < 1 );
            debug("Executing qualifier " . $block);
            if ($debug) {
                $ret_eval = &$block($rec);
            } else {
                eval { $ret_eval = &$block($rec); };
            }
            $retval = $retval & $ret_eval;
        }
    }

    if ( defined $QUALIFIERS->{$type}->{$gen}->{$sid} ) {

        # A decision was made to operate on this GEN:SID, reset retval.
        $retval = 1;

        debug("Executing qualifier for " . $type . ":" . $gen . ":" . $sid);

        foreach my $block (@{$QUALIFIERS->{$type}->{$gen}->{$sid}}) {
            last if ( $retval < 1 );
            debug("Executing qualifier " . $block);
            if ($debug) {
                $ret_eval = &$block($rec);
            } else {
                eval { $ret_eval = &$block($rec); };
            }
            $retval = $retval & $ret_eval;
        }
    }

    if ( defined $QUALIFIERS->{'PCRE'}->{$gen}->{$sid} && defined $rec->{'pkt'} ) {

        debug("Handling PCRE for" . $gen . ":" . $sid);

        foreach my $pcre (@{$QUALIFIERS->{'PCRE'}->{$gen}->{$sid}}) {
            last if ( $retval < 1 );
            debug("checking " . $pcre);
            $ret_eval = ( $rec->{'pkt'} =~ m/($pcre)/ );
            $retval = $retval & $ret_eval;
        }
    }

    return $retval;
}


sub readSnortUnifiedRecord() {
    my $rec = undef;

    if ( $UF->{'TYPE'} eq $UNIFIED_ALERT || $UF->{'TYPE'} eq $UNIFIED_LOG ) {
        $rec = old_readSnortUnifiedRecord();
        while ( $rec == -1 ) {
            $rec = old_readSnortUnifiedRecord();
        }
    } elsif ( $UF->{'TYPE'} eq $UNIFIED2 ) {
        $rec = readSnortUnified2Record();
        return if not defined $rec;
        while ( $rec == -1 ) {
            $rec = readSnortUnified2Record();
            return if not defined $rec;
        }
    } else {
        print("readSnortUnifiedRecord does not handle " . $UF->{'TYPE'} . " files");
        return undef;
    }

    return $rec;
}

sub readSnortUnified2Record() {
    my @record = undef;
    if ( $UF->{'TYPE'} ne $UNIFIED2 ) {
        cluck("readSnortUnified2Record does not handle " . $UF->{'TYPE'} . " files");
        return undef;
    } else {
        debug("Handling $UF->{'TYPE'} file");
    }

    my $buffer = '';
    my $readsize = 0;
    my $pktsize = 0;
    my $size = 0;
    my $mtime = 0;
    my $fsize;
    my @fields;
    my $i=0;

    $UF_Record = undef;
    $UF->{'FILESIZE'} = (stat(UFD))[7];
    $UF->{'FILEMTIME'} = (stat(UFD))[9];

    # read in the header (type,length)
    ($size, $buffer) = readData(8, $UF->{'TOLERANCE'});
    if ( $size <= 0 ) {
        return undef;
    }

    ($UF_Record->{'TYPE'},$UF_Record->{'SIZE'}) = unpack("NN", $buffer);

    debug("Header type is " . $UF_Record->{'TYPE'} . " with size of " . $UF_Record->{'SIZE'});

    ($size, $buffer) = readData($UF_Record->{'SIZE'}, $UF->{'TOLERANCE'});

    if ($size <= 0) {
        return undef;
    }

    debug("Read a record of $size bytes");
    debug("Handling type " . $UF_Record->{'TYPE'});

    if ( $UF_Record->{'TYPE'} eq $UNIFIED2_PACKET ) {
        debug("Handling a packet record from the unified2 file");
        $UF_Record->{'FIELDS'} = $log2_fields;
        debug("Unpacking with mask " . $unified2_type_masks->{$UNIFIED2_PACKET});
        @record = unpack($unified2_type_masks->{$UNIFIED2_PACKET}, $buffer);
        foreach my $fld (@{$UF_Record->{'FIELDS'}}) {
            if ($fld ne 'pkt') {
                $UF_Record->{$fld} = $record[$i++];
                debug("Field " . $fld . " is set to " . $UF_Record->{$fld});
            } else {
                debug("Filling in pkt with " . $UF_Record->{'pkt_len'} . " bytes");
                $UF_Record->{'pkt'} = substr($buffer, $UF_Record->{'pkt_len'} * -1, $UF_Record->{'pkt_len'});
            }
        }
        exec_handler("unified2_packet", $UF_Record);

    } elsif ($UF_Record->{'TYPE'} eq $UNIFIED2_IDS_EVENT) {
        debug("Handling an IDS event from the unified2 file");
        $UF_Record->{'FIELDS'} = $alert2_fields;
        debug("Unpacking with mask " . $unified2_type_masks->{$UNIFIED2_IDS_EVENT});
        @record = unpack($unified2_type_masks->{$UNIFIED2_IDS_EVENT}, $buffer);
        foreach my $fld (@{$UF_Record->{'FIELDS'}}) {
            $UF_Record->{$fld} = $record[$i++];
            debug("Field " . $fld . " is set to " . $UF_Record->{$fld});
        }
        exec_handler("unified2_event", $UF_Record);
    } else {
        debug("Handling of type " . $UF_Record->{'TYPE'} . " not implemented yet");
        exec_handler("unified2_unhandled", $UF_Record);
        return undef;
    }

    exec_handler("unified2_record", $UF_Record);

    #if ( exec_qualifier($UF_Record->{'TYPE'},$UF_Record->{'sig_gen'},$UF_Record->{'sig_id'}, $UF_Record) ) {
    #    return $UF_Record;
    #}

    # presume something is not right
    return -1;
}



sub read_records() {
  while ( $record = readSnortUnifiedRecord() ) {
    if ( $UF_Data->{'TYPE'} eq 'LOG' ) {
        print_log($record,$sids,$class);
    } else {
        print_alert($record,$sids,$class);
    }
  }
  return 0;
}

sub get_msg($$$$) {
    my $sids = $_[0];
    my $gen = $_[1];
    my $id = $_[2];
    my $rev = $_[3];

    if ( defined $sids->{$gen}->{$id}->{'msg'} ) {
        if ( defined $sids->{$gen}->{$id}->{$rev}->{'msg'} ) {
            return $sids->{$gen}->{$id}->{$rev}->{'msg'};
        } else {
            return $sids->{$gen}->{$id}->{'msg'};
        }
    } else {
        return "RULE MESSAGE UNKNOWN";
    }
}

sub get_class($$) {
    my $class = $_[0];
    my $classid = $_[1];

    return get_class_type($class,$classid);
}

sub get_class_type($$) {
    my $class = $_[0];
    my $classid = $_[1];

    if ( defined $class->{$classid}->{'type'} ) {
        return $class->{$classid}->{'type'};
    } else {
        return "unknown";
    }
}


sub get_priority($$$) {
    my $class = $_[0];
    my $classid = $_[1];
    my $pri = $_[2];
    $pri = 0 if not defined $pri;

    if ( $pri gt 0 ) {
        return $pri;
    } else {
        if ( $class->{$classid}->{'priority'} gt 0 ) {
            return $class->{$classid}->{'priority'};
        } else {
            return 0;
        }
    }
}


sub print_alert($$$) {
    print format_alert($_[0], $_[1], $_[2]);
    print("------------------------------------------------------------------------\n");
}

sub format_alert($$$) {
    my $rec = $_[0];
    my $sids = $_[1];
    my $class = $_[2];
    my $ret = "";

    my $time = gmtime($rec->{'tv_sec'});
    $ret = sprintf("%s {%s} %s:%d -> %s:%d\n" .
            "[**] [%d:%d:%d] %s [**]\n" .
            "[Classification: %s] [Priority: %d]\n", $time,
            $IP_PROTO_NAMES->{$rec->{'protocol'}},
            inet_ntoa(pack('N', $rec->{'sip'})),
            $rec->{'sp'}, inet_ntoa(pack('N', $rec->{'dip'})),
            $rec->{'dp'}, $rec->{'sig_gen'}, $rec->{'sig_id'},
            $rec->{'sig_rev'},
            get_msg($sids,$rec->{'sig_gen'},$rec->{'sig_id'},$rec->{'sig_rev'}),
            get_class($class,$rec->{'class'}),
            get_priority($class,$rec->{'class'},$rec->{'priority'}));

    foreach my $ref ($sids->{$rec->{'sig_gen'}}->{$rec->{'sig_id'}}->{'reference'}) {
        if ( defined $ref ) {
            $ret = $ret . sprintf("[Xref => %s]\n", $ref);
        } else {
            $ret = $ret . sprintf("[Xref => None]\n");
        }
    }
    return $ret;
}


sub print_log($$$) {
    print format_log($_[0], $_[1], $_[2]);
    print("=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+\n\n");
}

sub format_log($$$) {
    my $rec = $_[0];
    my $sids = $_[1];
    my $class = $_[2];
    my $eth_obj;
    my $ip_obj;
    my $tcp_obj;
    my $udp_obj;
    my $icmp_obj;
    my $time = gmtime($rec->{'pkt_sec'});
    my $ret = "";

    $ret = sprintf("[**] [%d:%d:%d] %s [**]\n[Classification: %s] [Priority: %d]\n",
            $rec->{'sig_gen'}, $rec->{'sig_id'}, $rec->{'sig_rev'},
            get_msg($sids,$rec->{'sig_gen'},$rec->{'sig_id'},$rec->{'sig_rev'}),
            get_class($class,$rec->{'class'}),
            get_priority($class,$rec->{'class'},$rec->{'priority'}));

    foreach my $ref ($sids->{$rec->{'sig_gen'}}->{$rec->{'sig_id'}}->{'reference'}) {
        if ( defined $ref ) {
            $ret = $ret . sprintf("[Xref => %s]\n", $ref);
        } else {
            $ret = $ret . sprintf("[Xref => None]\n");
        }
    }

    $ret = $ret . sprintf("Event ID: %lu     Event Reference: %lu\n",
            $rec->{'event_id'}, $rec->{'reference'});

    $eth_obj = NetPacket::Ethernet->decode($rec->{'pkt'});
    if ( $eth_obj->{type} eq ETHERNET_TYPE_IP ) {
        $ip_obj = NetPacket::IP->decode($eth_obj->{data});
        if ( $ip_obj->{proto} ne IP_PROTO_TCP && $ip_obj->{proto} ne IP_PROTO_UDP ) {
            $ret = $ret . sprintf("%s %s -> %s", $time, $ip_obj->{src_ip}, $ip_obj->{dest_ip});
        } else {
            if ( $ip_obj->{proto} eq IP_PROTO_TCP ) {
                $tcp_obj = NetPacket::TCP->decode($ip_obj->{data});
                $ret = $ret . sprintf("%s %s:%d -> %s:%d\n",
                    $time,
                    $ip_obj->{src_ip},
                    $tcp_obj->{src_port},
                    $ip_obj->{dest_ip},
                    $tcp_obj->{dest_port});
            } elsif ( $ip_obj->{proto} eq IP_PROTO_UDP ) {
                $udp_obj = NetPacket::UDP->decode($ip_obj->{data});
                $ret = $ret . sprintf("%s %s:%d -> %s:%d\n",
                $time,
                $ip_obj->{src_ip},
                $udp_obj->{src_port},
                $ip_obj->{dest_ip},
                $udp_obj->{dest_port});
            } else {
                # Should never get here
                print("DEBUGME: Why am I here - IP Header Print\n");
            }
        }
        $ret = $ret . sprintf("%s TTL:%d TOS:0x%X ID:%d IpLen:%d DgmLen:%d",
                $IP_PROTO_NAMES->{$ip_obj->{proto}},
                $ip_obj->{ttl},
                $ip_obj->{tos},
                $ip_obj->{id},
                $ip_obj->{len} - $ip_obj->{hlen},
                $ip_obj->{len});

        if ( $ip_obj->{flags} & $PKT_RB_FLAG ) {
            $ret = $ret . sprintf(" RB");
        }

        if ( $ip_obj->{flags} & $PKT_DF_FLAG ) {
            $ret = $ret . sprintf(" DF");
        }
        if ( $ip_obj->{flags} & $PKT_MF_FLAG ) {
            $ret = $ret . sprintf(" MF");
        }

        $ret = $ret . sprintf("\n");

        if ( length($ip_obj->{options}) gt 0 ) {
            my $IPOptions = decodeIPOptions($ip_obj->{options});
            foreach my $ipoptkey ( keys %{$IPOptions} ) {
                $ret = $ret . sprintf("IP Option %d : %s\n", $ipoptkey, $IPOptions->{'name'});
                $ret = $ret . format_packet_data($IPOptions->{'data'});
            }
        }

        if ( $ip_obj->{flags} & 0x00000001 ) {
            $ret = $ret . sprintf("Frag Offset: 0x%X   Frag Size: 0x%X",
                   $ip_obj->{foffset} & 0xFFFF, $ip_obj->{len});
        }

        if ( $ip_obj->{proto} eq IP_PROTO_TCP ) {
           $ret = $ret . sprintf("%s%s%s%s%s%s%s%s",
            $tcp_obj->{flags} & CWR?"1":"*",
            $tcp_obj->{flags} & ECE?"2":"*",
            $tcp_obj->{flags} & URG?"U":"*",
            $tcp_obj->{flags} & ACK?"A":"*",
            $tcp_obj->{flags} & PSH?"P":"*",
            $tcp_obj->{flags} & RST?"R":"*",
            $tcp_obj->{flags} & SYN?"S":"*",
            $tcp_obj->{flags} & FIN?"F":"*");
            $ret = $ret . sprintf(" Seq: 0x%lX  Ack: 0x%lX  Win: 0x%X  TcpLen: %d",
                   $tcp_obj->{seqnum},
                   $tcp_obj->{acknum},
                   $tcp_obj->{winsize},
                   length($tcp_obj->{data}));
            if ( defined $tcp_obj->{urg} && $tcp_obj->{urg} gt 0 ) {
                $ret = $ret . sprintf("  UrgPtr: 0x%X", $tcp_obj->{urg});
            }
            $ret = $ret . sprintf("\n");

            if ( length($tcp_obj->{options}) gt 0) {
                my $TCPOptions = decodeTCPOptions($tcp_obj->{options});
                foreach my $tcpoptkey ( keys %{$TCPOptions} ) {
                    $ret = $ret . sprintf("TCP Option %d : %s\n", $tcpoptkey, $TCPOptions->{$tcpoptkey}->{'name'});
                    $ret = $ret . format_packet_data($TCPOptions->{$tcpoptkey}->{'data'});
                }
            }
        } elsif ( $ip_obj->{proto} eq IP_PROTO_UDP ) {
            $udp_obj = NetPacket::UDP->decode($ip_obj->{data});
            $ret = $ret . sprintf("Len: %d\n", $udp_obj->{len});
        } elsif ( $ip_obj->{proto} eq IP_PROTO_ICMP ) {
            $icmp_obj = NetPacket::ICMP->decode($ip_obj->{data});
            $ret = $ret . sprintf("Type:%d  Code:%d  %s\n", $icmp_obj->{type}, $icmp_obj->{code}, $ICMP_TYPES->{$icmp_obj->{type}});
        } else {
            # Should never get here
            print("DEBUGME: Why am I here - TCP/UDP/ICMP Header print\n");
        }
    } else {
        $ret = $ret . sprintf("Linktype %i not decoded.  Raw packet dumped\n",
                $eth_obj->{type});
        $ret = $ret . format_packet_data($eth_obj->{data});
    }

    return $ret;
}



# CONFIG
$sids = get_snort_sids("/etc/snort/sid-msg.map",
                       "/etc/snort/gen-msg.map");
$class = get_snort_classifications("/etc/snort/classification.config");

# For test - could read ARGV
my $filename = qq(/var/tmp/snort.log.1296483099);

# RUN
$UF_Data = openSnortUnified($filename);
read_records();


