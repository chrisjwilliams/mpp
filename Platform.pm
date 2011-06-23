# -----------------------------------------------
# Platform
# -----------------------------------------------
# Description: 
# Interface for accessing and manipulating virtual 
# machines.
#
# Configuration Options:
# [network]
# hostname=
# ip=
#
# [workspace]
# dir=
#
# [packager]
# installCmd=apt-get install
# type=apt|yum
#
# [manager]
# type=VMWareESXi|Eucalyptus
# name=<name of Platform describing the manager platform>
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new()      : new object
# startup()  : startup the machine
# shutdown() : shutdown the machine
# revert()   : revert the machine to the last checkpointed disk
# invoke( string, log )            : invoke the command on the machine
# work( workspace, command, @args) : invoke the cammand in the specified workspace
#                                    commands : args
#                                    unpack     filename
# upload( location, @files )       : upload the stated files to the machines work area
# download( remote_workspace, localdir, @files )

package Platform;
use strict;
use Carp;
use MppClass;
use File::Basename;
use File::Spec;
use Net::Ping;
use Net::SSH;
use Net::SCP;
use File::SearchPath;
use RemoteFileHandle;
use PackageInfo;
use Socket;
use Report;
use FileHandle;
use Context;
our @ISA=qw /MppClass/;
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self=$class->SUPER::new(@_);
    $self->{config}=shift;
    $self->{name}=shift;
    $self->{dataPath}=shift;
    $self->{pm_api}=shift;
    $self->{api}=shift;
    $self->{context}=shift || die( "Must provide an execution context for platform $self->{name}\n" );
    $self->{srcPath}=$self->{api}->path();
    $self->{lastCheckTime}=0;

    # --- Remote Commands -----------
    my $cmdhash = $self->{config}->vars("commands") || {};
    foreach my $requiredCmds ( qw(perl python) ) {
        if( ! defined $cmdhash->{$requiredCmds} ) { $cmdhash->{$requiredCmds} = $requiredCmds };
    }
    $self->{perl}=$cmdhash->{perl};
    $self->{python}=$cmdhash->{python};
    my $commands=Environment->new( $cmdhash );
    $commands->namespace("command");
    
    $self->{chrootcmd}=$self->{config}->var("commands","chroot") || "sudo /usr/sbin/chroot";
    $self->{urlcmd}=$self->{config}->var("commands","fetchURL") || "/usr/bin/wget";
    my $p=$self->{config}->var("commands","remoteModulePath");
    $self->{remotePath}=File::SearchPath->new( $p );
    if( defined $self->{srcPath} )
    {
        $self->{remotePath}->add( $self->{srcPath}->paths() );
    }

    # --- minimum specification checks
    die "system platform not defined", if ( ! defined $self->{config}->var("system","platform"));
    die "system arch not defined", if ( ! defined $self->{config}->var("system","arch"));

    # --- networking defaults --------
    # ip not necessarily the ip - just a convenience to access
    $self->{ip}=$self->{config}->var("network","ip");
    if( ! defined $self->{ip} || $self->{ip} eq "" )
    {
        $self->{ip} = $self->{config}->var("network","hostname");
    }
    if( ( ! defined $self->{ip} || $self->{ip} eq "" ) && ! defined $self->_getController() )
    {
        $self->{ip}="127.0.0.1";
        $self->{hostname}="localhost";
    }
    if( ! defined  $self->{hostname} )
    {
         $self->{hostname}=$self->{ip};
    }

    $self->{verbosePrefix}.=$self->{name}.": ";

    # -- ssh ----
    $self->{envcmd}="";
    $self->{user}=$self->{config}->var("network","login");
    if( ! defined $self->{user} ) {
        $self->{user}=getpwuid $<;
    }
    bless $self, $class;

    $self->{workdir} = $self->{config}->var("workspace","dir");
    if( ! defined $self->{workdir} )
    {
        $self->{workdir} = "/home/".$self->{user}."/WorkDir";
    }

    # -- set up expansion variables
    $self->{env}=Environment->new( { arch=>$self->arch(),
                                     platform=>$self->platform(),
                                     type=>$class } );
    $self->{env}->namespace("platform");
    $self->{env}->add($commands);

    return $self;
}

sub env {
    my $self=shift;
    return $self->{env};
}

sub expandString {
    my $self=shift;
    my $string=shift;
    return $self->env()->expandString($string);
}

sub command {
    my $self=shift;
    my $cmd=shift;

    return $self->{config}->var("commands",$cmd) || $cmd;
}

sub config {
    my $self=shift;
    my $section=shift;
    my $var=shift;
    return $self->{config}->var($section,$var);
}

sub getConfig {
    my $self=shift;
    return $self->{config};
}

sub hostname {
    my $self=shift;
    return $self->{hostname};
}

sub broadcastAddress {
    my $self=shift;
    if(! defined $self->{broadcast}) {
        $self->{broadcast}=$self->{config}->var("network","broadcast");
    }
    return $self->{broadcast};
}

sub ip {
    my $self=shift;
    if( ! defined $self->{ip} )
    {
        # -- perhaps the controller knows
        my $controller=$self->_getController();
        if( defined $controller ) {
            return $controller->platformIP($self);
        }
    }
    return $self->{ip};
}

sub platform {
    my $self=shift;
    return $self->{config}->var("system","platform");
}

sub arch {
    my $self=shift;
    return $self->{config}->var("system","arch");
}

sub setArch {
    my $self=shift;
    return $self->{config}->setVar("system","arch",shift);
}

sub name {
    my $self=shift;
    return $self->{name};
}

sub setLoginUser {
    my $self=shift;
    $self->{user}=shift;
}

sub shutdown {
    my $self=shift;

    my $cmd=$self->{config}->var("shutdown", "cmd");
    if ( defined $cmd && $cmd ne "" ) 
    {
        my @args = ( $cmd );
        my $result = system(@args); 
        if( ! $result ) { 
            print " Failed:\n$cmd\n $!\n";
            exit 1;
        }
    }
    else {
        if( $self->_getController() ) {
            $self->{controller}->stopPlatform( $self );
        }
        elsif( defined $self->_getServer() )
        {
            eval {
                $self->{server}->
                    command( "stop",($self->{config}->var("vmware", "id")) );
            };
            if( $@ ) {
                print "shutdown failed : $@\n";
            }
        }
    }
}

sub startup {
    my $self=shift;
    my $log=shift;

    my $report=new Report();
    if( ! $self->isPresent() ) {
        print "Attempting to start machine ", $self->{name}, " ....\n";
        # -- run any startup command
        my $cmd=$self->{config}->var("startup", "cmd");
        if ( defined $cmd && $cmd ne "" ) 
        {
            my @args = ( $cmd );
            my $result = system(@args); 
            if( ! $result ) { 
                print " Failed:\n$cmd\n $!\n";
                exit 1;
            }
        }
        else {
            # -- vmware server
            if( $self->_getController() ) {
                $self->verbose("Asking controller to start ".$self->name());
                eval {
                    $report=$self->{controller}->startPlatform( $self );
                };
                if($@) {
                     if( ref($@) eq "Report" ) {
                        print "starting failed with return value : ", $@->returnValue(),"\n";
                        print $@->stdout(),"\n";
                        print $@->stderr(),"\n";
                        $report=$@;
                     }
                }
            }
            elsif( $self->_getServer() ) {
                my $id=$self->{config}->var("vmware", "id");
                $self->{server}->command("start", $id );
            }
            elsif( defined $self->{config}->var("network", "mac") )  {
                # -- wake on lan
                $self->verbose("Attempting to wake-on-lan ".$self->hostname());
                my $mac=$self->{config}->var("network", "mac");
                $self->_wake($mac,($self->broadcastAddress()||$self->ip()));
            }
        }
        my $sec=$self->{config}->var("system", "bootDelay");
        if( defined $sec ) {
            if( $sec=~/^\d+$/ ) {
                sleep( $sec );
            }
            else { die "bad format for bootDelay : $sec" };
        }
        $self->initialise($log);
    }
    return $report;
}

sub initialise {
    my $self=shift;
    if( $self->{config}->definedSection("startup") ) {
        $self->verbose("running startup commands");
        foreach my $cmd ($self->{config}->list("startup")) {
            $self->verbose("running startup command: $cmd");
            $self->invoke($cmd, @_);
        }
    }
}

#
# Get the controller object where the machine is managed by 
# some automated service ( e.g. in a cloud )
#
sub _getController {
    my $self=shift;
    if( ! defined $self->{controller} ) {
        # Determine the Platform for the Controller Box
        my $name=$self->{config}->var("manager", "server");
        my $platform;
        if( defined $name && $name ne "" ) {
           if( $name ne "localhost" ) {
               $platform=$self->{pm_api}->getPlatform($name, $self->{context});
           }
           else {
               $platform=$self->{pm_api}->localhost($name);
           }
           die("Platform: getController :unable to construct host $name") ,if( ! defined $platform );
        }
        else {
            return;
        }
        # instantiate the controller of the correct type
        my $type=$self->{config}->var("manager", "type");
        if( defined $type && $type ne "" ) {
            $self->{controller}=$self->{pm_api}->getController($type, $platform, $self->{context} );
            die "unknown controller type, ".$type, if( ! defined $self->{controller} );
        }
    }
    return $self->{controller};
}

sub _getServer {
    my $self=shift;
    # -- instantiate the vrtualisation server if appropriate
    my $type=$self->{config}->var("vmware", "id");
    if ( defined $type && $type ne "" ) {
    #    if( ! defined $self->{server} ) {
    #        my $servertype=$self->{config}->var("vmware", "serverType");
    #        if( defined $servertype ) {
    #            if( $servertype=~/^ESXiSSH/i ) {
    #                require VMWareESXiSSH;
    #                $self->{server}=VMWareESXiSSH->new( $self->{api},
    #                    $self->{config}->section("vmware"));
    #            }
    #            elsif( $servertype=~/^ESX/i ) {
    #                $self->{server}=VMWareESXi->new(
    #                    $self->{config}->section("vmware"));
    #            }
    #        }
    #        else {
    $self->{server}=VMWareServer->new( $self->{config}->section("vmware"));
    #        }
    #    }
    }
    return $self->{server};
}

sub cleanImageMount {
    my $self=shift;
    my $dir=shift;
    my $image=$self->{config}->var("workspace","diskImage")||"/";
    $image.="/", if($image !~/.*[\\\/]^/ );
    $image.=$dir, if(defined $dir);
    return $image;
}

# fullpathWorkingEnvironment(directory,log) 
# Similar to setupWorkingEnvironment but will
# prefix the path with  the ount point of any chroot environment
# if appropriate
#
sub fullpathWorkingEnvironment {
    my $self=shift;
    my $dir=$self->setupWorkingEnvironment(@_);
    if( $self->hasOverlay() ) {
        $dir=$self->cleanImageMount($dir);
    }
    return $dir;
}

# setupWorkingEnvironment(directory,log) 
# returns the location of the named working directory
# This will set up any overlay disks/chroot environments also

sub setupWorkingEnvironment {
    my $self=shift;
    my $name=shift;
    my $log=shift;

    my $dir=$name;
    $self->startup();
    croak("undefined directory"), if( ! defined $dir );
    if( $dir!~/^[\\\/]/ ) {
        $dir=$self->{workdir}."/".$name;
        if( ! defined $self->{workspaces}{$name} ) {
            #$self->_mkdir($self->{workdir});
            $self->_mkdir($dir);
            $self->{workspaces}{$name}=1;
        }
    }
    # --- create the MPP environment on the machine
    if( $self->hasOverlay() ) {
        $self->verbose("Setting up Overlay Disk");
        $self->setupOverlay("main",$log);
        $self->{envcmd}=$self->getChrootCmd($self->cleanImageMount(),$self->{user})." "; # switch on chroot
    }
    return $dir;
}

sub locations {
    my $self=shift;
    my $key=shift;

    if( ! defined $self->{typeLocations} )
    {
        #my $platdb=$self->{api}->packageFactory()->getDataBase($self);
        my $platdb=$self->{pm_api}->packageFactory()->getDataBase($self);
        $self->{typeLocations}=$self->{config}->section("locations");
        my $archkey="locations::".($self->arch());
        foreach my $key ( $platdb->vars($archkey) ) {
            if( ! defined $self->{typeLocations}{$key} ) {
                $self->{typeLocations}{$key}=$platdb->var($archkey, $key);
            }
        }
        foreach my $key ( $platdb->vars("locations") ) {
            if( ! defined $self->{typeLocations}{$key} ) {
                $self->{typeLocations}{$key}=$platdb->var("locations", $key);
            }
        }
        # -- some default values
        $self->{typeLocations}{"bin"}="/usr/bin", if ( !defined $self->{typeLocations}{bin} );
        $self->{typeLocations}{"config"}="/etc", if ( !defined $self->{typeLocations}{config} );
        $self->{typeLocations}{"lib"}="/usr/lib", if ( !defined $self->{typeLocations}{lib} );
        $self->{typeLocations}{"shared"}=$self->{typeLocations}{"lib"}, if ( !defined $self->{typeLocations}{shared} );
        $self->{typeLocations}{"script_lib"}="/usr/lib", if ( !defined $self->{typeLocations}{script_lib} );
        $self->{typeLocations}{"data"}="/usr/share", if ( !defined $self->{typeLocations}{data} );
        $self->{typeLocations}{"doc"}="/usr/share/doc", if ( !defined $self->{typeLocations}{doc} );
        $self->{typeLocations}{"man"}="/usr/share/man", if ( !defined $self->{typeLocations}{man} );
        $self->{typeLocations}{"include"}="/usr/include", if ( !defined $self->{typeLocations}{include} );
        $self->{typeLocations}{"python_lib"}=$self->{typeLocations}{"lib"}."/python/site-packages", if ( !defined $self->{typeLocations}{python_lib} );
    }
    return $self->{typeLocations};
}


sub updatePackageInfo {
    my $self=shift;
    my $type=$self->packageManagerType();
    my $manager=$self->_getPackageManager($type);
    my $cmd=$manager->updatePackageInfoCommand();
    $self->invoke($cmd, @_), if ( defined $cmd && $cmd ne "");
}

sub addPackageRepository {
    my $self=shift;
    my $type=$self->packageManagerType();
    my $manager=$self->_getPackageManager($type);

    $manager->addRepository(@_);
}

sub removePackageRepository {
    my $self=shift;
    my $type=$self->packageManagerType();
    my $manager=$self->_getPackageManager($type);

    $manager->removeRepository(@_);
}

sub installPackages {
    my $self=shift;
    my $log=shift;

    my $rv=0;
    if( defined $log && ! $log->isa("GLOB") ) {
        unshift @_, $log;
        undef $log;
    }
    # -- get the package publication method for this platform
    my $type=$self->packageManagerType();
    my $manager=$self->_getPackageManager($type);
    my @packages;
    if( $#_ >= 0 ) {
        my $cmd=$manager->installPackageCommand(@_);
        $rv=$self->invoke($cmd, $log), if ( defined $cmd && $cmd ne "");
    }
    return $rv;
}

sub uninstallPackages {
    my $self=shift;
    my $log=shift;
    if( ! $log->isa("GLOB") ) {
        unshift @_, $log;
        undef $log;
    }

    # -- get the package publication method for this platform
    my $type=$self->packageManagerType();
    my $manager=$self->_getPackageManager($type);

    if( $#_ >= 0 ) {
        my $cmd=$manager->uninstallPackageCommand(@_);
        $self->invoke($cmd, $log), if ( defined $cmd && $cmd ne "");
    }
}

sub isPresent {
    my $self=shift;
    my $time = time();
    if( $time  - $self->{lastCheckTime} > 10  || $self->{lastCheckResult} == 0 ) {
        if( $self->_getController() )
        {
            $self->{lastCheckTime} = $time;
            $self->{lastCheckResult} = $self->_getController()->isPresent($self);
        }
        elsif( $self->ip() )
        {
            #my $p = Net::Ping->new( "tcp", 5, 64 );
            my $p = Net::Ping->new( "tcp", 12, 64); # proto, timeout, bytes
                $self->verbose("checking ip ".($self->{ip}));
            $self->{lastCheckTime} = $time;
            $self->{lastCheckResult} = $p->ping($self->{ip});
        }
        else { 
            $self->{lastCheckResult} = 0;
        }
    }
    return $self->{lastCheckResult};
}

sub mkdir {
    my $self=shift;
    my $workspace=$self->fullpathWorkingEnvironment(shift);
    my $dir=$workspace."/".(shift);
    $self->_mkdir($dir);
}

sub _mkdir {
    my $self=shift;
    my $dir=shift;
    
    $self->invoke($self->getMkdirCommand()." ".$dir);
    #my $scp = Net::SCP->new( { "host"=>$self->{ip}, "user"=>$self->{user} } );
    #$scp->mkdir( $dir ) or die "cannot make dir $dir :".$scp->{errstr};
}

sub work {
    my $self=shift;
    my $dir=shift;
    my $cmd=shift;
    my $log;
    if( defined $cmd && $cmd->isa("GLOB") ) {
        $log=$cmd;
        $cmd=shift;
    }
    my $workspace=$self->setupWorkingEnvironment($dir,$log);
    croak( "cmd not defined" ), if(! defined $cmd);
    if( $cmd eq "unpack" )
    {
        # -- should do this with inheritance but for now....
        my $file = $workspace."/".(shift);
        my($filename, $directories, $suffix) = fileparse($file, '\..*');
        my $cmd="";
        if( $suffix =~ /zip/i ) {
            $cmd="unzip";
        }
        elsif( $suffix =~ /tar$/i )
        {
            $cmd="tar -xf";
        }
        elsif( $file =~ /tar.gz$/i || $suffix=~/tgz/i )
        {
            $cmd="tar -xzf";
        }
        elsif( $file =~ /tar.bz2$/i || $suffix=~/tbz/i ) {
            $cmd="tar -xjf";
        }
        if( $cmd ne "" ) {
            print $log "unpacking file with $cmd in $workspace\n", if (defined $log);
            return $self->invoke("cd $workspace; $cmd $file;", $log);
        }
        else {
            die ("Unknown file type ( $suffix )");
        }
    }
    elsif( $cmd eq "copy" ) {
        @_ == 2 or croak "usage: copy src destination (@_)";
        #return $self->remoteSubroutine( $dir, $log, "copyFiles", @_ );
        return $self->invoke("cd $workspace; cp -r -p $_[0] $_[1];", $log);
        #print "copy $_[0] $_[1]";
    }
    elsif( $cmd eq "link" ) {
        @_ == 2 or croak "usage: link target_file link_name (@_)";
        return $self->remoteSubroutine( $dir, $log, "linkFiles", @_ );
    }
    elsif( $cmd eq "run" ) {
        if( defined $_[0] )
        {
            #print $log $self->hostname(), ">@_\n";
            return $self->invoke("cd $workspace; @_;", $log);
        }
        else {
            die ("request to run with an empty command");
        }
    }
    elsif( $cmd eq "exec" ) {
        my $file=$self->{workspace}."/".(shift);
        print "executing $file with exec\n";
        return $self->invoke("cd $workspace; exec $file;", $log);
    }
}

#
# fetch the url to the cache directory
# 
sub fetchURL {
    my $self=shift;
    my $log=shift;
    if( ref($log) ne "GLOB" ) {
        unshift @_, $log; $log=undef;
    }
    $self->invoke($self->getFetchURLCmd(@_), $log);
}

sub getRmdirCommand {
    my $self=shift;
    my @cmds=();
    foreach(@_) {
        next, if( $_ eq "/" ); # now lets not be silly!
        push @cmds, "rm -rf $_";
    }
    return join("; ", @cmds);
}

sub getMkdirCommand {
    my $self=shift;
    return "mkdir -p @_";
}

sub getCopyCommand {
    my $self=shift;
    return "cp -r @_";
}

sub link {
    my $self=shift;
    my $target=shift;
    my $lnk=shift;
    $self->invoke($self->getLinkCommand($target,$lnk),@_);
}


sub getLinkCommand {
    my $self=shift;
    my $target=shift;
    my $lnk=shift;
    return "sudo ln -f -s $target $lnk";
}

sub getFetchURLCmd {
    my $self=shift;
    my $localcache=shift;
    my @urls=@_;
    return "cd $localcache; ".$self->{urlcmd}." @urls";
}

sub getChrootCmd {
    my $self=shift;
    my $dir=shift;
    my $user=shift||$self->{user};
    return $self->{chrootcmd}." -u ".$self->{user}." $dir /bin/bash -c ";
}

sub hasOverlay {
    my $self=shift;
    return 0;
}

sub invoke {
    my $self=shift;
    my $cmd=shift;
    my $log=shift;

    my $report = new Report();
    $report = $self->startup();

    $self->verbose("invoke($cmd)");
    # -- check for controller invocation
    my $controller=$self->_getController();
    if( defined $controller ) {
        $report = $controller->executePlatform($self,$self->{user}, $cmd,$log);
        if( defined $log ) {
                print $log $report->stdout();
                print $log $report->stderr();
        }
    }
    else {
        # -- use ssh if there is no controller
        $report=$self->invokeSSH($cmd,$log);
    }
    if( ! $report->returnValue() ) { $self->{lastCheckTime} = time(); }
    return $report;
}

sub invokeSSH {
    my $self=shift;
    my $cmd=shift;
    my $log=shift;

    if( defined $self->{user} && $self->{user} ne "" && defined $self->ip() )
    {
        my $out="";
        $cmd=$self->{envcmd}.$cmd;
        if( ! defined $log ) {
            #$log = FileHandle->new(">&main::STDOUT");
            #croak "log undefined";
        }
        print $log $self->{hostname}.">",$cmd,"\n", if( defined $log );
        my $SOUT=FileHandle->new();
        my $pid;
        my $report=Report->new();
        if( defined $log ) {
            # combine STDOUT and STDERR
            $pid=Net::SSH::sshopen3($self->{user}."\@".$self->ip(), undef, $SOUT, $SOUT, "$cmd");
            while( <$SOUT> ) {
                $report->addStdout($_);
                print $log $_;
                $out.=$_;
            }
        }
        else {
            # seperate STDOUT and STDERR
            my $SERR=FileHandle->new();
            $pid=Net::SSH::sshopen3($self->{user}."\@".$self->ip(), undef, $SOUT, $SERR, "$cmd");
            while( <$SOUT> ) {
                $report->addStdout($_);
                $out.=$_;
            }
            while( <$SERR> ) {
                $report->addStderr($_);
                $out.=$_;
            }
            $SERR->close();
        }
        $SOUT->close();
        waitpid $pid, 0;
        my $res=$? >> 8;
        $report->setReturnValue($res);
        if ( $res !=0 ) {
           my $msg=$self->name()." (".$self->{ip}.")> FAILED executing \"$cmd\" : $res\n";
           $msg.=$out."\n";
           die $msg;
        }
        return $report; #, if( ! defined $log );
        #return $out;
    }
    else { die("login or ip not set for ssh") }
}

#sub invokeOLD {
#    my $self=shift;
#    my $cmd=shift;
#    my $log=shift;
#
#    $self->startup();
#
    # -- ssh connection
#    if( defined $self->{user} && $self->{user} ne "" )
#    {
#        $self->verbose( $self->{hostname},">",$cmd,"\n");
#        my $res;
#        $cmd=$self->{envcmd}.$cmd;
#        eval {
            #if( ! defined $log ) {
            #    $res=Net::SSH::ssh_cmd( { user => $self->{user}, host => $self->{ip},
            #            command => $cmd } );
            #}
            #else {
#            if( ! defined $log ) {
#                $log = FileHandle->new(">&main::STDOUT");
#            }
#            print $log $self->{hostname}.">",$cmd,"\n";
#            my $SOUT=FileHandle->new();
#            my $SERR=FileHandle->new();
#            Net::SSH::sshopen3("$self->{user}\@$self->{ip}", undef, $SOUT, $SOUT, "$cmd") || die "ssh: $!";
#            while( <$SOUT> ) {
#                print $log $_;
#                $res.=$_;
#            }
#            $SOUT->close();
            #while( <$SERR> ) {
            #    print $log $_;
            #}
            #$SERR->close();
#            print $log "\n";
#        };
#        if($@) {
#            die $self->{hostname}.":command '$cmd' failed: $@ \n";
#        }
#        $self->verbose( "invoke() returns $res" );
#        return $res;
#    }
#    else { die("login not set for ssh") }
#}

#
# rdir = base directory on server
# localdir = directory on local machine to dowload files to
# @files - list of files relative to rdir to download
#
sub download {
    my $self=shift;
    my $rdir=shift;
    my $localdir=shift;
    
    my $controller = $self->_getController();
    if( ! $controller ) {
        return $self->downloadSSH( $self->{user}, $rdir, $localdir, @_);
    }
    else {
        if( ! File::Spec->file_name_is_absolute( $rdir ) ) {
            $rdir=$self->fullpathWorkingEnvironment($rdir);
        }
        $controller->download( $self, $self->{user}, $rdir, $localdir, @_ );
    }
}

sub downloadSSH {
    my $self=shift;
    my $username=shift;
    my $rdir=shift;
    my $localdir=shift;
    if( ! File::Spec->file_name_is_absolute( $rdir ) ) {
        $rdir=$self->fullpathWorkingEnvironment($rdir);
    }
    my @files=@_;

    $self->startup();
    my $scp = Net::SCP->new( { "host"=>$self->{ip}, "user"=>$username } );
    my @localFiles=();
    foreach my $file ( @files )
    {
        chomp $file;
        $self->verbose("getting file from: ", $rdir."/".$file, " to: ", $localdir, "\n");
        $scp->get($rdir."/".$file, $localdir ) or die $scp->{errstr};
        push @localFiles, $localdir."/".basename($file);
    }
    return @localFiles;
}

sub upload {
    my $self=shift;
    my $dir=shift;
    my @files=@_;
    
    if( ! File::Spec->file_name_is_absolute( $dir ) ) {
        $dir=$self->fullpathWorkingEnvironment($dir);
    }
    $self->verbose("uploading @files to $dir");
    # -- construct the file copy hash
    my $hash={};
    foreach my $f ( @files )
    {
        $hash->{$f}=$dir."/".basename($f);
    }
    my $controller = $self->_getController();
    if( ! $controller ) {
        #return $self->uploadSSH( $self->{user}, $dir, @_ );
        return $self->copyFileSCP( $hash, $self->{user} );
    }
    else {
        return $controller->upload( $self, $self->{user}, $hash );
    }
}

#sub uploadSSH {
#    my $self=shift;
#    my $username=shift;
#    my $dir=shift;
#    my @files=@_;
#
#    if( $dir!~/^[\\\/]/ ) {
#        $dir=$self->fullpathWorkingEnvironment($dir);
#    }
#
#    $self->startup();
#    my $scp = Net::SCP->new( { "host"=>$self->{ip}, "user"=>$self->{user} } );
#    $scp->mkdir( $dir ) or carp 'cannot make dir \''.$dir."' : ".$scp->{errstr};
#    foreach my $file ( @files )
#    {
#        $self->verbose("uploading file $file to $dir");
#        $scp->put($file, $dir ) or die "error uploading file $file :".$scp->{errstr};
#    }
#}

sub copyFile {
    my $self=shift;
    my $src=shift;
    my $dest=shift;
    my $log=shift;

    my $dir=dirname($dest);
    if( ! File::Spec->file_name_is_absolute( $dir ) ) {
        $dir=$self->fullpathWorkingEnvironment($dir);
    }
    my $dfile=$dir."/".(basename($dest));
    $self->_mkdir($dir);
    my $hash = { $src=>$dfile };

    my $controller = $self->_getController();
    if( ! $controller ) {
        return $self->copyFileSCP( $hash, $self->{user}, $log );
    }
    else {
        return $controller->upload( $self, $self->{user}, { $src=>$dfile } );
    }
}

sub copyFileSCP {
    my $self=shift;
    my $files= shift; #hash of src=>dest
    my $user=shift;
    my $log=shift;

    my $scp = Net::SCP->new( { "host"=>$self->{ip}, "user"=>$user } );
    foreach my $src ( keys %{$files} ) {
        my $dest=$files->{$src};
        my $dir=dirname($dest);
        $dir=$self->fullpathWorkingEnvironment($dir);
        $self->startup();
        $scp->mkdir( $dir ) or die "cannot make dir $dir :".$scp->{errstr};
        my $dfile=$dir."/".(basename($dest));
        my $cpyinfo="copy file \"$src\" to \"$dfile\" on ".$self->{ip}."\n";
        $self->verbose($cpyinfo);
        print $log $cpyinfo, if( defined $log );
        $scp->put($src, $dfile ) or die "unable to copy file $src to '$dfile' on $self->{ip},$self->{user}:".$scp->{errstr};
    }
}

sub packageType {
    my $self=shift;
    if( ! defined $self->{packageType} ) {
        my $type=$self->{config}->var("packager","packageType");
        if( ! defined $type ) {
            # -- set defaults according to package manager
            my $pm=$self->packageManagerType();
            if( $pm=~/apt$/i ) { $type = "debian"; }
            elsif( $pm =~/yum$/i ) { $type = "rpm" }
            elsif( $pm =~/zypper$/i ) { $type = "rpm" }
            else { $type = $pm }
        }
        $self->{packageType}=$type;
    }
    return $self->{packageType};
}

sub packageManagerType {
    my $self=shift;
    return $self->{config}->var("packager","type");
}

sub publisherType {
    my $self=shift;
    my $pmgr=$self->{config}->var("packager","publisher");
    if( ! defined $pmgr )
    {
        $pmgr=$self->packageManagerType();
    }
    return $pmgr;
}

sub workDir {
    my $self=shift;
    return $self->{workdir};
}

sub setWorkDir {
    my $self=shift;
    $self->{workdir} = shift;
}

sub fileExists {
    my $self=shift;
    my $file=shift;

    my $rv=1;
    eval { $self->invoke("ls '$file' >/dev/null", @_) };
    if($@) {
        $rv=0;
    }
    return $rv;
}

sub rmFile {
    my $self=shift;
    my $file=shift;

    if( $self->fileExists( $file, @_ ) )
    {
        return $self->invoke("rm '$file'" );
    }
    return 0;
}

sub remoteSubroutineCommand {
    my $self=shift;
    my $cmd=shift;
    
    my $remoteStore="mpp";
    my $perlexe=$self->setupWorkingEnvironment($remoteStore)."/bin/$cmd";
    #if ( ! $self->fileExists( $perlexe ) ) {
        # -- find a corresponding package in the Remote lookup path
        #    and copy it across
        my @files=$self->{remotePath}->find( "Remote/".$cmd.".pm" );
        die "unknown remote subroutine '$cmd'", if( $#files < 0 );

        require Module::ScanDeps;
        my $rv_ref =  Module::ScanDeps::scan_deps($files[0]); # find the dependencies
        #$self->copyFile($files[0], $remoteStore."/Remote/".$cmd.".pm");
        foreach my $key ( keys %$rv_ref ) {
            if( ! defined $self->{uploaded}{$key} ) {
                my $f=$rv_ref->{$key}{file};
                # copy dependencies available locally
                if( $self->{remotePath}->exists($key) )
                {
                    $self->verbose("remoteScript dependency : ".$remoteStore."/".$key);
                    $self->copyFile($f, $remoteStore."/".$key );
                    $self->{uploaded}{$key}=1;
                }
            }
        }
        # create a suitable script
        my $fh=RemoteFileHandle->new($self);
        $fh->open(">".$perlexe) or die ( "unable to open file $perlexe $!\n" );
        print $fh "#!".$self->{perl}." -I ".($self->setupWorkingEnvironment($remoteStore))."\n",
        "use strict;\n",
        "use Remote::$cmd;\n",
        "my \$remote={};\n", # placeholder to pass state info object
        "eval {\n",
        "\tmy \$rv=Remote::$cmd"."::".$cmd."(\$remote, \@ARGV);\n",
        "\tprint \$rv;\n",
        "};\n",
        "if(\$\@) { print STDERR \$\@; exit 1 };\n",
        "exit 0;\n";
        $fh->close() or die ( "problems writing file $!\n" );
        #}
    return ($self->{perl})." ".$perlexe;
}

# install and run a remoteSubroutine
sub remoteSubroutine {
    my $self=shift;
    my $workspace=shift;
    my $log=shift;
    my $cmd=shift;

    my $perlexe=$self->remoteSubroutineCommand($cmd);
    $workspace=$self->setupWorkingEnvironment($workspace);
    return $self->invoke("cd $workspace; $perlexe @_");
}

#
# return the package names for this platform
# mode=build|runtime
# packages to be provided as a list of hashes of the form { name=>"package_name" version=>"version_string" }
#
sub packageNames {
    my $self=shift;
    my $mode=shift;

    my @rv;
    foreach my $pkg ( $self->packageInfo( @_) ) {
         push @rv,$pkg->packageNames($mode);
    }
    return @rv;
}

sub packageInfo {
    my $self=shift;

    my @rv;
    foreach my $package ( @_ ) {
         push @rv, $self->_getPackageInfo($package->{name}, $package->{version} );
    }
    return @rv;
}

sub platformManager {
    my $self=shift;
    return $self->{pm_api};
}
   

# -- private methods --------------------

sub _getPackageInfo {
    my $self=shift;
    my $name=shift;
    my $version=shift;
    #return $self->{api}->getSoftwareManager()->packageInfo($self,$name,$version);
    return $self->{pm_api}->packageFactory()->getPackage($self,$name,$version);
}

sub _getPackageManager {
    my $self=shift;
    my $type=$self->packageManagerType();
    my $pf=$self->{api}->getPublisherFactory();
    my $manager=$pf->getPackageInstaller($type, $self);
    croak "unknown packageManager '$type'", if( ! defined $manager );
    return $manager;
}


# Wake method is adapted from the wakeonlan project 
# and is released under the Perl Artistic License
#
# http://gsd.di.uminho.pt/jpo/software/wakeonlan/
# by:    Jose Pedro Oliveira <jpo[at]di.uminho.pt>
#        Ico Doornekamp <ico[at]edd.dhs.org>
#
#
# The 'magic packet' consists of 6 times 0xFF followed by 16 times
# the hardware address of the NIC. This sequence can be encapsulated
# in any kind of packet, in this case an UDP packet targeted at the
# discard port (9).
#                                                                               

sub _wake
{
    my $self=shift;
        my $hwaddr  = shift;
        my $ipaddr  = shift || '255.255.255.255';
        my $port    = shift ||  getservbyname('discard', 'udp');

        my ($raddr, $them, $proto);
        my ($hwaddr_re, $pkt);

        # Validate hardware address (ethernet address)

        $hwaddr_re = join(':', ('[0-9A-Fa-f]{1,2}') x 6);
        if ($hwaddr !~ m/^$hwaddr_re$/) {
                warn "Invalid hardware address: $hwaddr\n";
                return undef;
        }

        # Generate magic sequence

        foreach (split /:/, $hwaddr) {
                $pkt .= chr(hex($_));
        }
        $pkt = chr(0xFF) x 6 . $pkt x 16;

        # Allocate socket and send packet

        $raddr = gethostbyname($ipaddr);
        $them = pack_sockaddr_in($port, $raddr);
        $proto = getprotobyname('udp');

        socket(S, AF_INET, SOCK_DGRAM, $proto) or die "socket : $!";
        setsockopt(S, SOL_SOCKET, SO_BROADCAST, 1) or die "setsockopt : $!";

        print "Sending magic packet to $ipaddr:$port with $hwaddr\n";

        send(S, $pkt, 0, $them) or die "send : $!";
        close S;
}

