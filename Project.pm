# -----------------------------------------------
# Project
# -----------------------------------------------
# Description:
# Main Functions for Product Generation
#
# File format is INI:
#
# [platform::name]  <--- one section for each platform
# publish=location_description_string
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new(INIConfig, MPPApi, ProjectInfo)    : new object
# name()   : name of the project
# build()  : launch build/pack operations
# test([platformlist])   : launch test install of built packages

package Project;
use INIConfig;
use Platform;
use File::Basename;
use ReleaseLevel;
use Carp;
use Config;
use threads;
use FileHandle;
use FileExpander;
use ProjectAnnounce;
use ProjectInfo;
use BuildStep;
use TestStep;
use Context;
use Report;
use Package::Package;
use strict;
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self={};
    $self->{config}=shift;
    $self->{api}=shift;
    $self->{project}=shift;
    $self->{publication}=shift;
    if( ! defined $self->{publication} ) { croak "no publication specifed"; }
    $self->{verbose}=$self->{config}->var("verbose","Project");
    $self->{verbose}=0, if( !defined $self->{verbose});
    $self->{loc}=$self->{project}->projectDir();
    $self->{work}=$self->{loc}."/mpp_work"; # local work area
    if( ! -d $self->{work} )
    {
        mkdir $self->{work};
    }
    #$self->{workspace} = $self->{project}->name()."_".$self->{project}->version(); # remote workspace
    bless $self, $class;

    # setup the context object
    $self->{context} = new Context( $self->id() );
    $self->{context}->setWorkDir( $self->{work} );

    # setup the execution steps
    $self->{managers}{build} = new BuildStep("build", $self->{context},$self->{work}, $self, $self->{api} );
    #$self->{managers}{test}->depends($self->{managers}{build});


    return $self;
}

sub workspace {
    my $self=shift;
    my $platform=shift;
    if( ! defined $self->{workspace} ) {
        $self->{workspace} = $self->{project}->name($platform)."_".$self->{project}->version(); # remote workspace
    }
    return $self->{workspace};
}

sub executionSteps {
    my $self=shift;
    return values %{$self->{managers}};
}

sub name {
    my $self=shift;
    return $self->{project}->name(@_);
}

sub version {
    my $self=shift;
    return $self->{project}->version();
}

sub id {
    my $self=shift;
    return $self->{project}->name()."__".$self->{project}->version();
}

sub location {
    my $self=shift;
    return $self->{loc};
}

sub verbose {
    my $self=shift;
    if( $self->{verbose} )
    {
        for ( @_ ) {
            print $_, "\n", if (defined $_ );
        }
    }
}

sub setOptions {
    my $self=shift;
    my $opt=shift;
    my $val=shift;

    if( defined $opt) {
        $self->{options}{$opt}=$val;
        print "Project: Setting Option : $opt\n";
        foreach my $packager ( keys %{$self->{packager}} ) {
            $packager->{config}->setList("options", $opt);
        }
    }
}

#
# return list of platforms the build failed on
#
sub buildFailed {
    my $self=shift;
    my $rv=0;
    foreach my $name ( keys %{$self->{built}} ) {
        foreach my $platform ( keys %{$self->{built}{$name}} ) {
            ++$rv, if( $self->{built}{$name}{$platform} ne 0);
        }
    }
    return $rv;
}

sub packageName {
    my $self=shift;
    my $platform=shift;
    my $packager=$self->_getPackager($self->workspace($platform), $platform, $self->{project});
    return $packager->projectName();
}

sub setBuildProcedure {
    my $self=shift;
    my $platform=shift;
    $self->{buildproc}{$platform->name()}=shift;
}

sub build {
    my $self=shift;
    my @platforms=@_;

    if( $#platforms < 0 )
    {
        @platforms=$self->platforms("build");
    }
    # -- build custom dependencies
    my $report;
    if( $self->{project}->type() eq "build" ) {
        $report = $self->{managers}{build}->execute( @platforms );
    }
    return $report;
    #return $self->{managers}{build}->status();
}

sub statusPlatform { 
    my $self=shift;
    my $type=shift||croak("must specify status type");
    my $platform=shift||croak("statusPlatform: must specify a platform");
    return $self->{managers}{$type}->platformStatus($platform);
}

sub statusString {
    my $self=shift;
    my $string="";
    foreach my $platform ( $self->platforms() ) {
        while (my ($stage,$manager) = each %{$self->{managers}}) {
            $string .= $platform->name().":".$stage.":".($manager->platformStatus($platform))."\n";
        }
    }
    return $string;
}

sub test {
    my $self=shift;
    my $publication=shift;
    my $release = shift;
    my @platforms=@_;

    if( $#platforms <= 0 )
    {
        @platforms=$self->platforms("test");
    }
    my $testManager = new TestStep("test", $self->{context},$self->{work} , $self, $release, $publication);
    return $testManager->execute( @platforms );
}

sub _buildPlatform {
    my $self=shift;
    my $platform=shift;
    my $log = shift;
    my @repositories=@_;

    my $workspace=$self->workspace($platform);
    my $rv=0;

    croak "no platform defined", if ( ! defined $platform );
    my $localwork=$self->_localwork($platform);
    my $packager=$self->_getPackager($workspace, $platform, $self->{project});

    # -- install any repositories
    my @reps;
    foreach my $rep ( @repositories ) {
        push @reps,$self->_installReps($platform, $rep, $log);
    }
    push @reps,$self->_platformRepositories($log,$platform);
    if( scalar @reps ) {
        $platform->updatePackageInfo($log) , if( ! defined $self->{options}{no_deps} );
    }

    # copy over the source code and unpack it
    my $srcPack=$self->{project}->srcPack();
    if( ! defined $self->{options}{no_patch} ) {
        my @patches=($packager->patches());
        for( @patches ) {
            if( defined $_ && $_ ne "" ) {
                $srcPack->patch($self->{loc}."/".$_);
            }
        }
    }
    # -- prepare the source code
    my $src;
    if( defined $srcPack && defined ($src=$srcPack->packageFile()) )
    {
        if( ! defined $self->{options}{no_upload} ) {
            if( $src!~/^\// )
            {
                $src=$self->{loc}."/".$src;
            }
            die "unable to find source package '", $src, "'\n" , if( !-e $src );
            my $wk=$packager->srcUploadDir($self);
            $wk=$workspace, if( ! defined $wk );
            $platform->upload( $wk, $src );
            if( -f $src && ($wk eq $workspace) ) {
            # -- only unpack src if its transfered to our workdir
                print $platform->name()."> unpacking source....\n";
                eval {
                    $platform->work( $workspace, $log, "unpack", basename($src) );
                };
            }
        }
    }
    else {
        $self->verbose("no srcPack defined\n");
    }

    # copy any defined files
    # format of copy:
    # srcfile destfile
    # (srcfile1 dest1) (srcfile2 dest2) ....
    my $copy=$packager->buildInfo("copy");
    my $srcDir=$self->{project}->srcDir();
    {
        # within these braces, workspace includes the srcDir
        my $workspace=$self->workspace($platform)."/$srcDir", if( defined $srcDir && $srcDir ne "" );
        if( defined $copy )
        {
            $self->verbose("copying files\n");
            foreach my $fileItem ( split( /\)\s+\(/, $copy ) ) {
                $fileItem=~s/^\s*\(?\s*(.*)\)?\s*/$1/;
                $fileItem=~s/^(.+)\)\s*$/$1/;
                my @ds = split( /\s+/, $fileItem );
                die "bad format for copy ($#ds items) format required \"(src dst) (src dst) ...\" = '$fileItem'", if ($#ds != 1);
                my $local=$self->{loc}."/".$ds[0];
                die "file $local does not exist", if( ! -f $local );
                my $remfile=$self->{project}->expandVars($ds[1]);
                $remfile=$workspace."/".$remfile, if( $remfile!~/^[\\\/]/);
                $platform->copyFile( $local, $remfile, $log );
            }
        }
        my $copyex=$packager->buildInfo("copyExpand");
        if( defined $copyex )
        {
            $self->verbose("copying expanded files\n");
            my $env=$self->_environment($platform);
            $env->merge($packager->env());
            $self->_copyExpandFiles($log, $platform, $copyex, $packager, $workspace);
        }
        my $link=$packager->buildInfo("link");
        if( defined $link )
        {
            $self->verbose("linking files\n");
            foreach my $fileItem ( split( /\)\s+\(/, $link ) ) {
                $fileItem=~s/^\s*\(?\s*(.*)\)?\s*/$1/;
                $fileItem=~s/^(.+)\)\s*$/$1/;
                my @ds = split( /\s+/, $fileItem );
                die "bad format in configuration for [build] link= ($#ds items) = '$fileItem'", if ($#ds != 1);
                my $file=$self->{project}->expandVars($ds[0]);
                my $link=$self->{project}->expandVars($ds[1]);
                $link=$platform->workDir()."/".$workspace."/".$link, if( $link!~/^[\\\/]/);
                $file=$platform->workDir()."/".$workspace."/".$file, if( $file!~/^[\\\/]/);
                $platform->link($file,$link,$log);
            }
        }

        # install any dependencies
        #print $log "========================== MPP BUILD START =================================\n";
    }

        # perform the build
        $self->buildPlatformVariant($self->{project}, $platform, $workspace, $log); 
        #$rv=$packager->build($localwork, $log, $self->{loc} );
        #print $log "========================== MPP BUILD END ==================================\n";

        # clean up
        my $shutdown=0; # done at a higher level now
        if( $shutdown ) { 
            # -- shutdown the machine
            $platform->shutdown();
        }
        else {
            if( $self->_removeReps($platform, $log, @reps ) ) {
                $platform->updatePackageInfo($log) , if( ! defined $self->{options}{no_deps} );
            }
        }
#}; # end eval
#if( $@ ) {
#    if( ref( $@ ) eq "Report" )
#    {
#         print $log "failed with error :", $@->returnValue(),"\n",
#                    $@->stdout(),"\n", $@->stderr();
#    }
#    else {
#        print $log $@;
#    }
#    #$self->_errors($platform, "build", $@);
#}
    my $report = new Report();
    $report->setReturnValue($rv);
    return $report;
}

sub dependencies {
    my $self=shift;
    my $type=shift;

    # return a list of SoftwareDependency objects
    my @deps;
    my $swmgr = $self->{api}->getSoftwareManager();
    foreach my $hash ( $self->{project}->dependencies()->dependencies($type) )
    {
        push @deps, $swmgr->getPackage($hash->{name}, $hash->{version});
    }
    return @deps;
}

sub buildPlatformVariant {
    my $self=shift;
    my $variant=shift;
    my $platform=shift;
    my $workspace=shift;
    my $log=shift;

    my $name=$variant->name($platform);
    my @variants=$variant->variants();
    $self->verbose("building variant $name in $workspace");
    # -- if no variants are defined, consider this variant to be a buildable project
    if( $#variants < 0 ) {
        # -- configuration file procedures
        my $proc=$variant->getProcedure("build");
        if( defined $proc ) {
            $proc->execute( $log, $platform->workDir()."/".$workspace );
        }
        # -- internal project Procedures
        $proc=$self->{buildproc}{$platform->name()};
        if( defined $proc ) {
            $proc->execute( $log, $platform->workDir()."/".$workspace );
        }
        if( $variant->buildable() ) {
            $self->verbose("variant $name in $workspace is buildable");
            if( ! defined $self->{built}{$name}{$platform} ) {
                my $localwork=$self->_localwork($platform);
                my $packager=$self->_getPackager($workspace, $platform, $variant);
                print $log "=== MPP package ",$name," START ==========================\n";
                $platform->installPackages( $log, $self->_buildDependencies( $platform, $packager ) ), if( ! defined $self->{options}{no_deps} );
                print $log "--- MPP BUILD ",$name," START ----------------------------\n";
                my $rv=$packager->build( $localwork, $log, $self->{loc} );
                print $log "--- MPP BUILD ",$name," END   ----------------------------\n";
                print $log "=== MPP package ",$name," END ============================\n";
                $self->{built}{$name}{$platform}=$rv;
            }
        }
    }
    else {
        foreach my $var ( @variants ) {
            $self->buildPlatformVariant($var, $platform, $workspace, $log );
        }
    }
}


sub setPlatforms {
    my $self=shift;
    if( @_ ) {
        $self->{config}->clearList("platforms");
        foreach my $item ( @_ ) {
            $self->{config}->setList("platforms", $item );
        }
        undef $self->{platforms};
    }
}

#
# add a list of software package dependencies to the 
# specified dependency list (one on "build","test", or generic represented by "")
# addDependencies(list, @packages)
#
sub addDependencies {
    my $self=shift;
    $self->{project}->dependencies()->addDependencies(@_);
}

#
# remove a list of software package dependencies from the
# specified dependency list (one on "build","test", or generic represented by "")
# addDependencies(list, @packages)
#
sub removeDependencies {
    my $self=shift;
    $self->{project}->dependencies()->removeDependencies(@_);
}

sub addPlatforms {
    my $self=shift;
    foreach my $item ( @_ ) {
        $self->{config}->setList("platforms", $item );
    }
}

sub removePlatforms {
    my $self=shift;
    foreach my $item ( @_ ) {
        $self->{config}->removeItemFromList("platforms", $item );
    }
}

sub platforms {
    my $self=shift;
    if( ! defined $self->{platforms} ) {
        # -- get the configuration list
        my @platforms=$self->{config}->list("platforms");
        my @contextplatforms;
        # -- find any substitutes from the publication
        if( $self->{publication} ) {
            foreach my $p ( @platforms ) {
                push @contextplatforms, $self->{publication}->platformSubstitution($p, @_);
            }
        }
        else {
            @contextplatforms=@platforms;
        }
        @{$self->{platforms}}=$self->{api}->getContextualisedPlatforms( $self->{context}, @contextplatforms);
    }
    return @{$self->{platforms}};

}

sub getPlatforms {
    my $self=shift;
    return $self->{api}->getContextualisedPlatforms( $self->{context},@_);
}

sub hasPlatform {
    my $self=shift;
    my $name=shift;
    return (defined $self->platform($name))?1:0;
}

sub platform {
    my $self=shift;
    my $name=shift;

    my $platform;
    foreach my $plat ( $self->platforms() )
    {
        $platform=$plat, if ($plat->name() eq $name);
    }
    return $platform;
}

sub packageFile {
    my $self=shift;
    my $platform=shift;
    return $self->{config}->var("platform::".$platform->name(),"packageFileName");
}

#
# Install the published project from the specified release/publication
#
sub install {
    my $self=shift;
    my $platform=shift;
    my $release=shift;
    my $publication=shift;
    my $log=shift;
    if( ! defined $log ) {
        $log=FileHandle->new(">&main::STDOUT");
    }
    # -- add publication to platfrom for package dependencies
    my @reps=();
    if( defined $release && defined $publication ) {
        @reps=$publication->setupRepositories( $log, $release, $platform );
    }
    # -- publish self to the test repo
    my $name=$self->packageName($platform);
    $platform->updatePackageInfo($log);;
    $platform->installPackages($log, $name);
    if( $#reps >= 0 ) {
        $publication->removeRepositories($log, $platform, @reps);
        $platform->updatePackageInfo($log);
    }
}

# -- private methods -------------------------
sub _platformRepositories {
    my $self=shift;
    my $log=shift;
    my $platform=shift;
    my $version=shift||"pre-release"; # nasty hack

    my @reps;
    my $packager=$self->_getPackager($self->workspace($platform), $platform, $self->{project});
    my $rep=$packager->buildInfo("useRepository");
    if( defined $rep ) {
        push @reps,$self->_installReps($platform, $rep, $log);
    }
    if( $self->{publication} ) {
        for($self->{publication}->setupRepositories($log,$version,$platform)) {
            push @reps, ReleaseLevel->new($version, $_);
        }
    }
    return @reps;
}

sub _installReps {
    my $self=shift;
    my $platform=shift;
    my $pubString=shift;
    my $log=shift;

    if( defined $pubString ) {
        my ($pub,$version) = split( /:/, $pubString );
        if( defined $pub && defined $version ) {
            my $pf=$self->{api}->getPublisherFactory();
            my $publisher=$pf->getPublisher( $pub );
#            $publisher->addRepository($platform, $version );
            print $log "adding repository ",$publisher->name(), " version: $version\n";
            $platform->addPackageRepository($log,$publisher,$version);
            return new ReleaseLevel($version, $publisher);
        }
        else {
            die "useRepository badly formed (need repository_name:release) : $pubString\n";
        }
    }
}

sub _removeReps {
    my $self=shift;
    my $platform=shift;
    my $log=shift;
    my @reps=@_;

    my $count=0;
    foreach my $rep ( @reps ) {
       my $release=$rep->level();
       print $log "removing repository ",$rep->repository()->name(), " version: $release\n";
       $platform->removePackageRepository($rep);
       $count++;
    }
    return $count;
    #if( defined $pubString ) {
        #my ($pub,$version) = split ( /:/, $pubString );
        #if( defined $pub && defined $version ) {
            #my $pf=$self->{api}->getPublisherFactory();
            #my $publisher=$pf->getPublisher( $pub );
            #$publisher->addRepository($platform, $version );
            #$platform->removePackageRepository($publisher, $version );
        #}
        #else {
            #die "useRepository badly formed (need repository_name:release) : $pubString\n";
        #}
    #}
}

sub _testPlatform {
    my $self=shift;
    my $platform=shift;
    my $log = shift;

    $self->verbose("testing on platform ".$platform->name());
    my $rv=new Report;
    my $localwork=$self->_localwork($platform);

    my $workspace=$self->workspace($platform);
    my $testdir=$workspace."/mpp_test";
    my $packager=$self->_getPackager($workspace, $platform, $self->{project});

    # ---- setup the testing environment
    my $binfo=BuildInfoMPP->new($self->{project},$platform,$workspace);
    $self->_copyFiles($log, $platform, $binfo->sectionInfo("test","copy") );
    $self->_copyExpandFiles($log, $platform, $binfo->sectionInfo("test","copyExpand"), $packager );
    $self->_unpack($log, $platform, $binfo->sectionInfo("test","unpack") );

    # -- run any tests
    my $cmd=$binfo->sectionInfo("test","cmd");
    if( defined $cmd &&  $cmd ne "" ) {
        $rv=$platform->work($testdir, $log, "run", $cmd);
    }

    return $rv;
}

sub getPackages { 
    my $self=shift;
    my $platform=shift;

    my @packs=();
    # -- get built packages
    if( $self->{project}->type() eq "build" ) {
        my $packager=$self->_getPackager($self->workspace( $platform ), $platform, $self->{project});
        my $pack=$self->{work}."/".$platform->name()."/";
        my @files=();
        for ( $packager->packageFiles() ) {
            if( -f $pack.$_ ) {
                push @files, $pack.$_;
            }
            else {
                print "No package '$_' available for platform : ", $platform->name(),"\n";
            }
        }
        my $pkg=Package::Package->new( { name=>$self->name($platform),
                                         version=>$self->version(),
                                         platform=>$platform->platform(),
                                         arch=>$platform->arch()
                                         }
                                     );
        $pkg->setFiles(@files);
        push @packs, $pkg;
    }
    # -- pre-packaged files
    push @packs, $self->{project}->prePackaged();
    return @packs;
}

sub isBuilt {
    my $self=shift;
    my $platform=shift;
    return $self->statusPlatform("build", $platform);
}

sub _platformSubstitute {
    my $self=shift;
    my $platform=shift; # Platform object
    if( defined $self->{publication} ) {
        my $pname=$platform->name();
        my $sname=$self->{publication}->platformSubstitution($pname);
        if( $pname ne $sname ) {
            $self->verbose("substituting platform $sname for $pname");
            my @platforms=$self->getPlatforms($sname);
            $platform=$platforms[0];
            if( ! defined $platform ) {
                die("substitue platform $sname does not exist");
            }
        }
    }
    return $platform;
}

sub _getPublisher {
    my $self=shift;
    my $platform=shift;
    require PublisherFactory;
    my $pf=$self->{api}->getPublisherFactory();
    return $pf->getPlatformPublishers($platform);
}

sub _getPackager
{
    my $self=shift;
    my $workspace=shift;
    my $platform=shift;
    my $info=shift;

    my $name=$info->name($platform);
    if ( ! defined $self->{packager}{$platform}{$name} )
    {
        my $type=$platform->packageType();
        if( ! defined $type ) {
            die "packageType not defined for ".($platform->name());
        }
        if( defined $self->{publication} ) {
            $self->{packager}{$platform}{$name}=$self->{publication}->getPackager($type, $platform, $workspace, $self->{config}, $info );
        }
        else {
            $self->{packager}{$platform}{$name}=$self->{api}->createPackager($type, $platform, $workspace, $self->{config}, $info );
        }
        # -- propagate options
        foreach my $opt ( keys %{$self->{options}} ) {
            $self->{packager}{$platform}{$name}->{config}->setList("options", $opt);
        }
        $self->{packager}{$platform}{$name}->setEnv("workdir",$workspace);
    }
    return $self->{packager}{$platform}{$name};
}

sub _localwork {
    my $self=shift;
    my $platform=shift;
    if( UNIVERSAL::isa($platform, 'Platform' ) ) {
        $platform=$platform->name();
    }
    #my $localwork=$self->{work}."/".$platform->name();
    my $localwork=$self->{work}."/".$platform;
    if( ! -d $localwork ) {
        mkdir $localwork or die ($self->name().": unable to create local working directory $localwork");
    }
    return $localwork;
}

sub _buildDependencies {
    my $self=shift;
    my $platform=shift;
    my $packager=shift;

    my $bd=$self->{config}->var("build::".$platform->name(), "buildDependencies");
    my @bud=();
    if( defined $bd )
    {
        @bud=split(/,/, $bd);
    }
    # -- add generic dependencies
    my $deps=$self->{project}->dependencies();
    foreach my $pkg ( $deps->platformDependencies($platform,"build"), $packager->buildDependencies() ) {
        push @bud,$pkg->packageNames("build");
    }
    return @bud;
}

sub _copyFiles {
    my $self=shift;
    my $log=shift;
    my $platform=shift;
    my $copy=shift;

    my $workspace=$self->workspace( $platform );
    if( defined $copy )
    {
        $self->verbose("copying files\n");
        foreach my $fileItem ( split( /\)\s+\(/, $copy ) ) {
            $fileItem=~s/^\s*\(?(.*)\)?\s*/$1/;
            $fileItem=~s/^(.+)\)\s*$/$1/;
            my @ds = split( /\s+/, $fileItem );
            die "bad format for copy ($#ds items) = '$fileItem'", if ($#ds != 1);
            my $local=$self->{loc}."/".$ds[0];
            die "file $local does not exist", if( ! -f $local );
            my $remfile=$self->{project}->expandVars($ds[1]);
            $remfile=$workspace."/".$remfile, if( $remfile!~/^[\\\/]/);
            $platform->copyFile( $local, $remfile, $log );
        }
    }
}

sub _environment {
    my $self=shift;
    my $platform=shift || die("specify a platform");
    require Environment;
    my $env=Environment->new($self->{project}->env());
    $env->add($platform->env());
    return $env;
}

sub _copyExpandFiles {
    my $self=shift;
    my $log=shift;
    my $platform=shift;
    my $copyex=shift;
    my $packager=shift;
    my $workspace=shift||$self->workspace( $platform );
    if( defined $copyex )
    {
        $self->verbose("copying expanded files (workspace=$workspace)\n");
        my $env=$self->_environment($platform);
        if( defined $packager ) {
             $env->merge($packager->env());
        }
        foreach my $fileItem ( split( /\)\s+\(/, $copyex ) ) {
            $fileItem=~s/^\s*\(?\s*(.*)\s*\)?\s*/$1/;
            $fileItem=~s/^\s*(.+)\s*\)\s*$/$1/;
            $self->verbose("copyExpand(): '$fileItem'");
            my @ds = split( /\s+/, $fileItem );
            die "bad format for copyExpand ($#ds items) = '$fileItem'", if ($#ds != 1);
            my $local=$self->{loc}."/".$ds[0];
            die "copyExpand: file \"$local\" does not exist", if( ! -f $local );
            my $remfile=$self->{project}->expandVars($ds[1]);
            $remfile=$platform->workDir()."/".$workspace."/".$remfile, if( $remfile!~/^[\\\/]/);
            my $fe=FileExpander->new($local, $env);
            my $fh=RemoteFileHandle->new($platform);
            print $log "expanding file $local to ".($platform->name()).":$remfile\n", if ( defined $log);
            $fh->open(">".$remfile) or die("unable to write file $remfile");
            $fe->copy($fh);
            $fh->close() or die("unable to write file $remfile");
        }
    }
}

sub _unpack {
    my $self=shift;
    my $log=shift;
    my $platform=shift;
    my $file=shift;

    if ( defined $file && $file ne "" ) {
        if( $file!~/^\// )
        {
            $file=$self->{loc}."/".$file;
        }
        $platform->upload( $self->workspace( $platform ), $file );
        if( -f $file ) {
            $self->verbose($platform->hostname()."> unpacking $file....");
            $platform->work( $self->workspace( $platform ), "unpack", basename($file) );
        }
    }
}
