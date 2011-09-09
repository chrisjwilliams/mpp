# ----------------------------------
# class Controller
# Description:
#  Abstract interface for Platfrom Controllers
#-----------------------------------
# Methods:
# new() :
# startPlatform(Platform )                : start up the specified platform
# stopPlatform(Platform )                 : stop a platform instance
# executePlatform(Platform, username)     : execute the commands on the specified platform
# loginPlatform(Platform, username)       : start up an interactive shell on the specified platform
# isPresent(Platform)                     : verify if the machine is up and running
# upload(Platform, username, { src=>dest } ) : upload the specfied files to the directory on the specified machine
# download(Platform, username, remotedir, localdir, @files)       : 
#
# save()                                 : save the context specific info
#-----------------------------------

package Controller;
use Context;
use MppClass;
our @ISA=qw /MppClass/;
use strict;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    my $config=shift;
    $self->{context} = shift;
    $self->{server} = shift || die("Controller: must provide a server");
    $self->{api} = shift;

    # -- construct the local configuration object
    $self->{config} = new INIConfig;
    $self->{config}->merge($config);
    $self->{config}->merge($self->{server}->getConfig());

    bless $self, $class;

    # -- set up active instances (machines) tracking configuration
    $self->{instanceInfo}=$self->{context}->getConfigINI("PlatformControllers/".($self->id()));
    
    return $self;
}

#
# returns the first matching variable from:
# 1) local config file
# 2) server config file
# 3) global configuration
#
sub configVar {
    my $self=shift;
    my $section=shift;
    my $var=shift;
    return $self->{api}->expandGlobals($self->{config}->var($section,$var)) or $self->{api}->configVar($section,$var);
}

sub save {
    my $self=shift;
    $self->{context}->saveINI("PlatformControllers/".($self->id()), $self->{instanceInfo} );
}

sub id {
    my $self=shift;
    my $name=ref($self)."_".($self->{server}->name());
    return $name;
}

sub invoke {
    my $self=shift;
    $self->verbose("controller execution: @_\n");
    #print "controller execution: @_\n";
    return $self->{server}->invoke( @_);
}

sub upload {
    my $self=shift;
    my $platform=shift;
    my $username=shift;
    my $filehash = shift;
    return $platform->copyFileSCP( $filehash , $username);
}

sub download {
    my $self=shift;
    my $platform=shift;
    my $username=shift;
    my $remoteDir=shift;
    my $localDir=shift;
    my @files=@_;
    return $platform->downloadSSH( $username, $remoteDir, $localDir, @files );
}

sub executePlatform {
    my $self=shift;
    my $platform=shift;
    my $username=shift;
    my $cmd=shift;
    my $log=shift;

    # -- default is to use ssh of the managed platform directly
    return $platform->invokeSSH($cmd,$log);
}

sub loginPlatform {
    my $self=shift;
    my $platform=shift;
    my $username=shift;

    # -- default is to use ssh of the managed platform directly
    return $platform->loginSSH();
}

sub platformIP {
    my $self=shift;
    my $platform=shift;
    my $ip=$self->platformInfo($platform,"ip");
    return $ip;
}

sub startPlatform {
    my $self=shift;
    my $platform=shift;
}

sub stopPlatform {
    my $self=shift;
    my $platform=shift;
}

sub isPresent {
    my $self=shift;
    my $platform=shift;
}

sub listPlatforms {
}

sub platformInfo {
    my $self=shift;
    my $platform=shift;
    my $var=shift;
    return $self->{instanceInfo}->var($platform->name(), $var );
}
   

sub getId {
    my $self=shift;
    my $platform=shift;
    my $id = $platform->{config}->var("manager", "id");
    die( "[manager] \"id\" not defined for platform :".($platform->name()) ), 
                if( ! defined $id || $id eq "" );
    return $id;
}
