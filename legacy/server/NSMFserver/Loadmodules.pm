


BEGIN {

    # list of NSMFmodules:: modules
    my @modules = map { "NSMmodules::$_" } qw/Snort Suricata Cxtracker PCAP PRADS/;
    my $bundle = 0;

    MODULE:
    for my $module (@modules) {

        # try to use local modules first
        eval "use $module";
        next MODULE unless($@);

        if($ENV{'DEBUG'}) {
            warn "Local $module not found. Trying to look in bundled modules instead.\n";
        }

        # use bundled modules instead
        # Path to wher NSMF has installed its modules should be use here
        local @INC = ("$FindBin::Bin/../modules");
        eval "use $module";
        die $@ if($@);
        $bundle++;
    }

    if($ENV{'DEBUG'} and $bundle) {
        warn "Run this command to install missing modules:\n";
        warn "\$ perl -MCPAN -e'install NSMframeworkmodules <- not working yet!'\n";
    }
}
