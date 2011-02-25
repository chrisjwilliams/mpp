# ----------------------------------
# class Controllers::EoverI
# Description:
#  A controller to use the EoverI cloud infrastructure
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Controllers::EoverI;
use strict;
use Controller;
use Platform;
our @ISA=qw /Controller/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    if ( !defined $self->{server} ) {
        die("Please specify a platform for the EoverI manager");
    }
    my $config=$self->{server}->getConfig();
    my $eoveri_dir = $self->{api}->getConfig->var("eoveri", "jarDir");
    #die("please specify location of the EoverI jar files : [eoveri] jarDir"), if( ! defined $eoveri_dir );

    # -- determine the main command to run the eoveri layer
    my $java = $config->var("eoveri", "java");
    $java = $self->{server}->command("java"), if( ! defined $java );
    my $eoveri_wrap=$self->{api}->externalsDir()."/EoverI"; # location of our wrapper
    #my $classpath=$eoveri_wrap.":".($eoveri_dir)."/*";
    #$self->{cmd}="$java -classpath \"".$classpath."\" EoverICLI";
    $self->{cmd}=$self->{api}->externalsDir()."/EoverI/zeeli-cli";
    my $usercert=$self->configVar("eoveri", "pem");
    my $trustcert=$self->configVar("eoveri", "trust");
    $self->{cmd}.=" -pem $usercert", if( defined $usercert );
    $self->{cmd}.=" -trust $trustcert", if( defined $trustcert );

    bless $self, $class;
    return $self;
}

sub executePlatform {
    my $self=shift;
    my $platform=shift;
    my $user=shift;
    my $cmd=shift;
    my $log=shift;
    my $instId = $self->instanceId($platform);
    if( defined $instId ) {
        $cmd="\"$cmd\""; # quote the command
        my $cmds=$self->{cmd}." execute \"$instId\" \"$user\" ".$cmd;
        return $self->invoke($cmds);
    }
}

sub startPlatform {
    my $self = shift;
    my $platform = shift;
    # start up an instance of the machine
    my $cmds=$self->{cmd}." start ";
    $cmds .= $self->imageId( $platform )." ".$self->hardwareId( $platform );
    my $rep=$self->invoke($cmds);
    if( $rep->returnValue() == 0 ) {
        # -- store the instance info for later use
        my $vars = _extractHash($rep->stdout());
        my $instanceId = $vars->{id};
        $self->verbose("started OK");
        if( defined $instanceId && $instanceId ne "" ) {
            $self->{ids}{$platform}=$instanceId;
            $self->verbose("instance id = \"".$instanceId."\"");
            $self->{instanceInfo}->setVar($platform->name(),"id", $instanceId);
            $self->save();
        }
        else {
            $self->verbose("unable to extract instance id from command output");
            $rep->addErrorMessage("unable to extract instance id from command output");
            die $rep;
        }
    }
    else {
        $self->verbose("start Failed");
        die $rep;
    }
}

sub upload {
    my $self=shift;
    my $platform = shift;
    my $username = shift;
    my $filehash = shift;

    my $instId = $self->instanceId($platform);
    if ( defined $instId ) {
        my $cmd=$self->{cmd}." upload \"".$instId."\" \"$username\"";
        my $fileline="";
        foreach my $file ( keys %{$filehash} )
        {
            if ( -f $file ) {
                $fileline.=" \"$file\" \"".$filehash->{$file}."\"";
            }
        }
        return $self->invoke($cmd.$fileline), if( $fileline ne "" );
     }
}


sub download {
    my $self=shift;
    my $platform = shift;
    my $username = shift;
    my $remoteDir=shift;
    my $localDir=shift;

    my $instId = $self->instanceId($platform);

    if ( defined $instId ) {
        my $cmd=$self->{cmd}." download \"".$instId."\" \"$username\"";
        foreach my $file (@_ )
        {
            $self->invoke($cmd." ".$remoteDir."/$file ".$localDir."/$file");
        }
     }
}

sub stopPlatform {
    my $self=shift;
    my $platform = shift;
    my $instId = $self->instanceId($platform);
    if ( defined $instId ) {
        $self->verbose("stopping \"".($platform->name())."\" \"".$instId."\"");
        my $cmds=$self->{cmd}." stop ".$instId;
        $self->invoke($cmds);
        $self->{instanceInfo}->removeVar($platform->name(),"id");
        $self->save();
    }
}

#
# Implementation of base class Interface method
#
sub isPresent {
    my $self=shift;
    my $platform=shift;

    $self->verbose("checking status of \"".($platform->name())."\"");
    my $instId = $self->instanceId($platform);
    if ( defined $instId ) {
        if( ! $self->{running}{$instId} ) {
            my $cmds=$self->{cmd}." status \"".$instId."\"";
            my $rep=$self->invoke($cmds);
            if( ! $rep->returnValue() ) {
                $self->verbose("status returns: \"".join(" ",$rep->stdout())."\"");
                 # extract the status from stdout 
                 my $s=grep( /running/, $rep->stdout());
                 $self->{running}{$instId}=$s;
                 return $s;
            }
        }
        else { return 1; }
    }
    $self->verbose("status of \"".($platform->name())."\" not found");
    return 0;
}

#
#  Get the instance id for any active instances
#
sub instanceId {
    my $self=shift;
    my $platform=shift;

    if( ! defined $self->{ids}{$platform} )
    {
        $self->{ids}{$platform} = 
               $self->{instanceInfo}->var($platform->name(),"id");
    }
    if( defined $self->{ids}{$platform} ) {
        $self->verbose("instance id for platform \"".($platform->name())."\" = \"".($self->{ids}{$platform})."\"");
    }
    else {
        $self->verbose("no instance id exists for platform \"".
                        ($platform->name())."\"");
    }
    return $self->{ids}{$platform};
}

#
# parse the output formt he caomand int a hash
#
sub _extractHash {
    my $hash={};
    foreach my $line ( @_ ) {
        next, if( $line!~/:/ );
        chop $line;
        my ($var, $value) = split ":",$line;
        $hash->{$var}=$value;
    }
    return $hash;
}


#
#  Get the instance id from the configuration
#
sub imageId {
    my $self=shift;
    my $platform=shift;
    my $id=$platform->{config}->var("eoveri", "id");
    die("{eoveri] id needs to be set in configuration file for machine: ".($platform->name())),
        if( ! $id );
    return $id;
}

#  Get the hardware type id from the configuration
sub hardwareId {
    my $self=shift;
    my $platform=shift;
    my $type=$platform->{config}->var("eoveri", "type");
    die("[eoveri] type needs to be set in configuration file for machine: ".($platform->name()))
        if( ! $type );
    return $type;
}
