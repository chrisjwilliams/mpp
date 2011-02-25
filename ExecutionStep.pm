# ----------------------------------
# class ExecutionStep
# Description:
#  Control the execution Process, logging and status
#-----------------------------------
# Methods:
# new() :
# executeStep()     : implement this method in an inheriting class
# status($platform) : returns the status of the step the last time it was run
#-----------------------------------


package ExecutionStep;
use Carp;
use Config;
use Platform;
use Report;
use FileHandle;
use threads;
use threads::shared;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{name}=shift || croak("must provide a name");
    $self->{context}=shift || croak("must set a context");
    #$self->{logBase} = shift;
    #if( ! -d $self->{logBase} )
    #{
    #    mkdir $self->{logBase};
    #}
    bless $self, $class;
    $self->{errors}=&share( {} );
    $self->{verbose}=0;
    return $self;
}

sub name {
    my $self=shift;
    return $self->{name};
}

sub depends {
    my $self=shift;
    foreach my $step ( @_ )
    {
        if( defined $step ) {
            push @{$self->{depends}}, $step;
        }
    }
}

sub executeStep {
    my $self = shift;
    my $platform = shift;
    my $log = shift;
    exit "Undefined step: Please inherit and override the executeStep() method";
}

sub execute {
    my $self=shift;
    my @platforms=@_;

    my $r = new Report;
    if ($Config{useithreads}) {
        my @threads;
        my $tplat={};
        # We have threads
        foreach my $platform ( @platforms )
        {
            my $thr=threads->create( \&executePlatform, $self,$platform );
            push @threads, $thr;
            $tplat->{$thr}=$platform;
        }
        foreach my $thr (@threads) {
            my $rep=$thr->join();
            $rep->{platform}=$tplat->{$thr}; # reconstruct object from other thread
            $r->addReport($rep);
        }
    } else {
        # - no threads, so do everything serially
        foreach my $platform ( @platforms )
        {
            $r->addReport($self->executePlatform($platform));
        }
    }
    return $r;
}

sub executePlatform {
    my $self=shift;
    my $platform=shift;

    my $rv = new Report($platform);
    my $logfile=$self->logFile($platform);
    my $log=FileHandle->new(">".$logfile); 
    if( ! defined $log )
    {
        $rv->addStderr("unable to open logfile $logfile : $!");
        $rv->setReturnValue( 1 );
        return $rv;
    }

    # -- check dependencies have been run
    foreach my $dep ( @{$self->{deps}} ) {
       my $depStatus = $dep->platformStatus($platform);
       if ( ! defined $depStatus || $depStatus != "completed" ) {
            $rv = $dep->executePlatform($platform);
            if( $rv->returnValue() != 0 ) {
                $self->_errors( $log, $platform, "error executing dependency \"".($dep->name())."\"" );
                return $rv;
            }
       }
    }

    # -- run the required step
    eval {
        $self->verbose("Executing");
        $rv = $self->executeStep($platform, $log);
    }; 
    if( $@ ) {
        $self->verbose("Failed");
        if( ref($@ ) eq "Report" ) {
            print $log $@->stdout();
            print $log $@->stderr();
            $rv->addStderr($@->stderr() );
            $rv->addStdout($@->stdout() );
            $rv->setReturnValue( 1 );
            $self->_errors($log, $platform, $@->stdout()."\n".$@->stderr());
        }
        else {
            $rv->addStderr($@);
            $rv->setReturnValue( 1 );
            print $log $@;
            $self->_errors($log, $platform, $@);
        }
    }
    # -- set the status
    if ( $rv->returnValue() != 0 ) {
        $self->verbose("Failed");
        $self->setPlatformStatus($platform, "failed" );
    }
    else {
        $self->setPlatformStatus($platform, "completed" );
    }
    return $rv;
}

sub _platformINI {
    my $self=shift;
    if( ! defined $self->{inidata} ) {
        $self->{inidata} = $self->{context}->getConfigINI($self->{name}."_status");
    }
    return $self->{inidata};
}

sub setPlatformStatus {
    my $self=shift;
    my $platform=shift;
    my $status=shift;

    my $ini = $self->_platformINI();
    $ini->setVar("platform::".$platform->name(),"status",$status);
    $ini->setList("platforms","",$platform->name()); # keep track of executed platforms
    $ini->save();
    $self->verbose("platform:".($platform->name())." status:".$status);
}

sub platformStatus {
    my $self=shift;
    my $platform = shift;

    return $self->_platformINI()->var("platform::".$platform->name(),"status") || "none";
}

sub logFile {
    my $self=shift;
    my $platform=shift;
    return $self->{context}->filename($platform->name(), "log_".$self->{name});
#    my $dir = $self->{logBase}."/".($platform->name());
#    if( ! -d $dir ) {
#        mkdir $dir;
#    }
#    return $dir."/log_".$self->{name};
}

sub errors {
    my $self=shift;
    my @rv;
    foreach my $platform ( keys %{$self->{errors}} ) {
        push @rv, $platform.": ".$self->{errors}{$platform};
    }
    return @rv;
}

sub verbose {
    my $self=shift;
    if( $self->{verbose} )
    {
        for ( @_ ) {
            print $self->{name},":",$_, "\n", if (defined $_ );
        }
    }
}

#sub platformsFailed {
#    my $self=shift;
#    return (keys %{$self->{errors}});
#}

sub _errors {
    my $self=shift;
    my $log=shift;
    my $platform = shift;
    my $txt=shift;
    print $log $txt;
    $self->{errors}{$platform->name()}=$txt;
}
