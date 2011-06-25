



=head2 read_socket_data

 Read data from a socket.
 Input the $socket descriptor.
 Output is the data collected?

=cut

sub read_socket_data {
  my $SOCK = shift;
  my $data = q();

  binmode($SOCK);
  while (defined(my $Line = <$SOCK>)) {
    #chomp $Line;
    #$Line =~ s/\r//;
    #last unless length $data;
    $data = "$data$Line";
  }

  return $data;
}


