=head2 ip_is_ipv6

 Check if an IP address is version 6
 returns 1 if true, 0 if false

=cut

sub ip_is_ipv6 {
    my $ip = shift;

    # Count octets
    my $n = ($ip =~ tr/:/:/);
    return (0) unless ($n > 0 and $n < 8);

    # $k is a counter
    my $k;

    foreach (split /:/, $ip) {
        $k++;

        # Empty octet ?
        next if ($_ eq '');

        # Normal v6 octet ?
        next if (/^[a-f\d]{1,4}$/i);

        # Last octet - is it IPv4 ?
        if ($k == $n + 1) {
            next if (ip_is_ipv4($_));
        }

        print "[*] Invalid IP address $ip";
        return 0;
    }

    # Does the IP address start with : ?
    if ($ip =~ m/^:[^:]/) {
        print "[*] Invalid address $ip (starts with :)";
        return 0;
    }

    # Does the IP address finish with : ?
    if ($ip =~ m/[^:]:$/) {
        print "[*] Invalid address $ip (ends with :)";
        return 0;
    }

    # Does the IP address have more than one '::' pattern ?
    if ($ip =~ s/:(?=:)//g > 1) {
        print "[*] Invalid address $ip (More than one :: pattern)";
        return 0;
    }

    return 1;
}

=head2 expand_ipv6

 Expands a IPv6 address from short notation

=cut

sub expand_ipv6 {

   my $ip = shift;

   # Keep track of ::
   $ip =~ s/::/:!:/;

   # IP as an array
   my @ip = split /:/, $ip;

   # Number of octets
   my $num = scalar(@ip);

   # Now deal with '::' ('000!')
   foreach (0 .. (scalar(@ip) - 1)) {

      # Find the pattern
      next unless ($ip[$_] eq '!');

      # @empty is the IP address 0
      my @empty = map { $_ = '0' x 4 } (0 .. 7);

      # Replace :: with $num '0000' octets
      $ip[$_] = join ':', @empty[ 0 .. 8 - $num ];
      last;
   }

   # Now deal with octets where there are less then 4 enteries
   my @ip_long = split /:/, (lc(join ':', @ip));
   foreach (0 .. (scalar(@ip_long) -1 )) {

      # Next if we have our 4 enteries
      next if ( $ip_long[$_] =~ /^[a-f\d]{4}$/ );

      # Push '0' until we match
      while (!($ip_long[$_] =~ /[a-f\d]{4,}/)) {
         $ip_long[$_] =~ s/^/0/;
      }
   }

   return (lc(join ':', @ip_long));
}


