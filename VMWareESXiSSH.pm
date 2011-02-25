# -----------------------------------------------
# VMWareESXiSSH
# -----------------------------------------------
# Description: 
#  Wrapper around the vmware ESXiSSH hypervisor
#
#
# -----------------------------------------------
# Copyright Chris Williams 2005
# -----------------------------------------------
# Interface
# ---------
# new()    : new object
# command() : run a command on the server
#

package VMWareESXiSSH;
use strict;
#use VMware::Vix::Simple;
#use VMware::Vix::API::Constants;
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self={};
    $self->{api}=shift;
    $self->{config} = shift;
    if( ! defined $self->{config}{server} )
    {
        die "vmware hypervisor not defined";
    }
    bless $self, $class;
    $self->setServer($self->{config}{server});

    return $self;
}

sub setServer {
    my $self=shift;
    $self->{config}{server}=shift;
    $self->{server}=$self->{api}->getPlatformManager()->getPlatform($self->{config}{server}, $self->{api}->getDefaultContext());
    die "unknown platform, ".($self->{config}{server}), if( ! defined $self->{server} );
}

sub command {
    my $self=shift;
    my $cmd=shift;

    my $cmds="/bin/vim-cmd ";
    if( $cmd eq "start" ) {
        $cmds.="vmsvc/power.on @_";
    }
    elsif( $cmd eq "stop" ) {
        $cmds.="vmsvc/power.off @_";
    }
    else {
        print "unsupported command $cmd\n";
        return;
    }
    $self->{server}->invoke($cmds);
}

#sub startvm($) {
#   my ($vh) = @_;
#   print "Here\n";
#   my $err = VMPowerOn($vh, 0, VIX_INVALID_HANDLE);
#   mydie("Failed to power on VM", $err) if $err != VIX_OK;
#   print "Here\n";
#}

#sub stopvm($) {
#    my ($vh) = @_;
#    my $err = VMPowerOff($vh, 0);
#    mydie("Failed to power off VM", $err) if $err != VIX_OK;
#}
# -- private methods -------------------------

#sub _openvm($$) {
#    my $self=shift;
#    my ($hh, $vmpath) = @_;
#    my $err;
#    my $handle;
#
#    ($err, $handle) = VMOpen($hh, $vmpath);
#    mydie("Failed to open VM $vmpath", $err) if $err != VIX_OK;
#
#    return $handle;
#}

#sub _hosthandle {
#    my $self=shift;
#    if( !defined $self->{hosthandle} )
#    {
#        my $err;
#        my $handle;
#
#        print "Connecting to $self->{config}{server}:$self->{config}{port}\n";
#        ($err, $handle) = HostConnect(VIX_API_VERSION,
#            VIX_SERVICEPROVIDER_VMWARE_SERVER,
#            $self->{config}{server}, $self->{config}{port},
#            $self->{config}{username}, $self->{config}{passwd},
#            0, VIX_INVALID_HANDLE);
#        mydie("Connect Failed", $err) if $err != VIX_OK;

#        print "Connected to $self->{config}{server}\n";
#        $self->{hosthandle}=$handle;
#    }
#    return $self->{hosthandle};
#}
