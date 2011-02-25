# -----------------------------------------------
# VMWareServer
# -----------------------------------------------
# Description: 
#  Wrapper around the vmware server system commands
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

package VMWareServer;
use strict;
#use VMware::Vix::Simple;
#use VMware::Vix::API::Constants;
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self={};
        $self->{config} = shift;
        if( ! defined $self->{config}{server} )
        {
        $self->{config}{server}="https://localhost:8333/sdk";
    }
    bless $self, $class;

    return $self;
}

sub setServer {
    my $self=shift;
    $self->{config}{server}=shift;
}

sub command {
    my $self=shift;
    my $cmd=shift;

#    if( $cmd eq "start" ) {
#       startvm(_openvm($self->_hosthandle(),shift @_));
#   }
#    elsif ( $cmd eq "stop" ) {
#        stopvm(@_);
#    }
    # -- default send the command to vmrun system command
#    else {
        my @cmds=(qw(/usr/bin/vmrun -T server -h),  $self->{config}{server}.":".$self->{config}{port}."/sdk", 
             "-u", $self->{config}{username}, "-p", $self->{config}{passwd});

         if ( system( @cmds, $cmd, @_) != 0 ) {
             if( $! ne "Operation now in progress" ) {
                 die("failed to execute @cmds $cmd @_ :\n$! : ".($? >> 8));
             }
         }
#   }
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
