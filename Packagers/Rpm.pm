# ----------------------------------
# class Packagers::Rpm
# Description:
#   Create RPM packages
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Packagers::Rpm;
use strict;
use Packagers::Packager;
use RemoteFileHandle;
use ProjectInfo;
use File::Basename;
our @ISA=qw /Packagers::Packager/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    #$self->{platform}=shift;
    #$self->{workdir}=shift;
    $self->{fullwork}=$self->{platform}->workDir()."/".$self->{workdir};
    #$self->{config}=shift;
    #$self->{project}=shift;
    die( "no package information provided" ), if ( ! defined $self->{project} );
    $self->{suffix}="rpm";

    $self->{release}=$self->buildInfo("release");
    $self->{release}=1, if( ! defined $self->{release} );

    # -- type locations
    $self->{typesLocations}=$self->{platform}->locations();
    $self->{fileTypePre} = { "doc"=>'%doc ', #prefixes for types of file in the spec file
                             "config"=>'%config '
                           }; 
    return $self;
}

sub dependencies {
    return ( { name=>"rpmtools" } );
}

sub arch {
    my $self=shift;
    my $arch=$self->SUPER::arch(@_);
    $arch = "noarch", if( $arch eq "any" || $arch eq "all" );
    return $arch;
}

sub projectName {
    my $self=shift;
    my $pname=$self->SUPER::projectName();
    return $pname;
}

sub packageRoot {
    my $self=shift;
    my $pname=$self->projectName();
    my $proot=$pname."-".$self->projVersion()."-".$self->{release};
    return $proot;
}

sub binPacks {
    my $self=shift;
    my @proot=( $self->packageRoot().".".($self->arch()).".rpm" );
    foreach my $sub ( $self->{project}->subpackages() ) {
        push @proot, $sub->name()."-".($sub->version())."-".$self->{release}.".".($self->arch($sub)).".rpm";
    }
    return @proot;
}

sub sourcePacks {
    my $self=shift;
    my $proot=$self->packageRoot();
    return $proot.".src.rpm";
}

sub packageFiles {
    my $self=shift;
    return ( $self->binPacks(), $self->sourcePacks() );
}

sub setup {
    my $self=shift;
    my $downloadDir=shift;
    my $log=shift;

    # -- create a tar from the src directory
    my $rpm=$self->_prepareDir();
    $self->{rpmDir}=$rpm;
    my $sources=$rpm."/SOURCES";
    my $srcPack=$sources."/".$self->projectName()."-".$self->projVersion().".tgz";
    my $srcDir=$self->{project}->srcDir();
    $self->remote($log, "tar -czf ".$srcPack." ".$srcDir);
    $self->{srcPack}=$srcPack;

    # invoke the setup commands
    $self->runCommands( $log, $self->{builder}->cleanCommands() );
    $self->runCommands( $log, $self->{builder}->setupCommands() );

    # create the top level spec file TODO

}

sub build {
    my $self=shift;
    my $downloadDir=shift;
    my $log=shift;

    $self->setup($downloadDir, $log );

    # -- copy src file to SOURCES
    #my $sources=$rpm."/SOURCES";
    #my $srcPack=$self->{project}->srcPack();
    my $srcDir=$self->{project}->srcDir();
    #die "unable to determine source code", if( ! defined $srcDir );

    my $rv=0;
    my @cmds=$self->{builder}->buildCommands();
    if( @cmds )
    {
        my $cmd="cd $srcDir && ".(join " && ", @cmds), if ( defined $srcDir && $srcDir ne "" );
        print $log "Building......\n";
        $rv=$self->remote($log,$cmd);
    }

    # -- install commands
    #$self->runCommands($log, $self->{builder}->installCommands());

    # -- launch rpmbuild for each variant
    my $project=$self->{project};
    my $rpm=$self->{rpmDir};
    foreach my $sub ( $project, $project->subpackages() ) {
        print $log "Packing ",$sub->name(),"\n";
        my $file=$self->_specFileSub($rpm, $sub);
        my $arch=$self->arch($sub);
        my $archcmd="";
        $archcmd=" --target=".$arch, if( defined $arch );
        my $builddir=$self->_builddir($sub);
        $self->remote($log, "rpmbuild$archcmd --buildroot $builddir --define '_topdir ".($self->{fullwork}."/".$rpm."' -ba \"".$file."\""));
    }
    foreach my $packt ( $self->sourcePacks() ) {
        $self->{platform}->download( $self->{workdir}, $downloadDir, $rpm."/SRPMS/$packt" );
    }
    foreach my $packt ( $self->binPacks() ) {
        (my $arch=$packt)=~s/.*\.(.+)\.rpm$/$1/;
        $self->{platform}->download( $self->{workdir}, $downloadDir, $rpm."/RPMS/".$arch."/$packt" );
    }
    return $rv;
}

sub projVersion {
    my $self=shift;
    if( ! defined $self->{pversion} ) {
        my $version=$self->{project}->version();
        $version=~s/-/./g; # remove illegal "-" chars in version
        $self->{pversion}=$version;
    }
    return $self->{pversion};
}

sub _prepareDir {
    my $self=shift;
    my $workdir=$self->{workdir};

    my $rpmdir="rpm";
    $self->{platform}->mkdir( $self->{workdir}, $rpmdir );
    my $builddir=$rpmdir."/BUILD";
    $self->{platform}->mkdir( $self->{workdir}, $builddir );
    my $rpmsdir=$rpmdir."/RPMS";
    $self->{platform}->mkdir( $self->{workdir}, $rpmsdir );
    my $srpmsdir=$rpmdir."/SRPMS";
    $self->{platform}->mkdir( $self->{workdir}, $srpmsdir );
    my $srcsdir=$rpmdir."/SOURCES";
    $self->{platform}->mkdir( $self->{workdir}, $srcsdir );
    my $specsdir=$rpmdir."/SPECS";
    $self->{platform}->mkdir( $self->{workdir}, $specsdir );

    return $rpmdir;
}

sub _builddir {
    my $self=shift;
    my $project=shift;
    my $builddir=$self->{fullwork}."/".$self->{builder}->dir($project->name());
    return $builddir;
}


sub _specFileSub {
    my $self=shift;
    my $rpm=shift;
    my $project=shift;
    #my $builddir=$self->{fullwork}."/".$rpm."/BUILD";
    my $builddir=$self->_builddir($project);
    my $specdir=$rpm."/SPECS";
    my $projname=$project->name();
    my $version=$self->projVersion();
    my $arch=$self->arch($project);
    my $desc=$project->summary();
    if( ! defined $desc || $desc eq "" ) {
        $desc="Nobody Knows";
    }
    my $depends=PackageInfo::standardNames("runtime",$project->dependencies()->platformDependencies($self->{platform},"runtime"),
                                           $project->dependencies()->platformDependencies($self->{platform},"optional"));
    my $provides=join(",",$project->provides());
    my $conflicts=$project->conflicts();
    my $replaces=$project->replaces();

    my $fh=RemoteFileHandle->new($self->{platform});
    my $spec=$projname."-".$version.".spec";
    my $specfile=$self->{fullwork}."/".$specdir."/".$spec;
    $fh->open(">".$specfile) or die ( "unable to open file $specfile $!\n" );
    # -- preamble
    print $fh "Name: ", $projname, "\n";
    print $fh "Version: ", $version, "\n";
    print $fh "Release: ", $self->{release}, "\n"; # this is rpm package version for re-packaging instances
    print $fh "License: ", $project->licence(),"\n";
    print $fh "Vendor: ", $project->vendor(),"\n";
    print $fh "Summary:", $desc,"\n";
    print $fh "Group: ", $project->group(), "\n";
    print $fh "URL: ", $self->{config}->var("project","url"),"\n", if ( defined $self->{config}->var("project","url") );
    my $packager= $self->{config}->var("project","packager");
    print $fh "Packager: $packager\n", if ( defined $packager );
    #print $fh 'BuildRoot: %{_builddir}/%{name}-root',"\n";
    print $fh 'BuildRoot: '.$builddir,"\n";
    print $fh "Source: ", $self->{srcPack}, "\n";
    print $fh "Requires:", $depends, "\n", if( defined $depends && $depends ne "" );
    print $fh "Provides:", $provides, "\n", if( defined $provides && $provides ne "" );
    print $fh "Obsoletes:", $replaces, "\n", if( defined $replaces && $replaces ne "" );
    print $fh "Conflicts:", $conflicts, "\n", if( defined $conflicts && $conflicts ne "" );

    print $fh "%description\n";
    foreach my $line ( $self->{project}->description() ) {
        print $fh "    ",$line,"\n";
    }
    print $fh "%prep\n\n";
    print $fh "%build\n";
    for( $self->{builder}->setupCommands($project) ) {
        print $fh $_,"\n";
    }
    for( $self->{builder}->installCommandsProject($project) ) {
        print $fh $_,"\n";
    }
    my @seperateSharedDir=$project->extraLibraryDirs();
    my @prescript=$self->{builder}->preInstallCommands();
    my @postscript=$self->{builder}->postInstallCommands();
    my @unprescript=$self->{builder}->preUninstallCommands();
    my @unpostscript=$self->{builder}->postUninstallCommands();
    if( $#seperateSharedDir >= 0  ) {
        push @postscript, "-p /sbin/ldconfig";
        push @unpostscript, "-p /sbin/ldconfig";
    }
    if( @prescript ) {
        print $fh '%pre',"\n";
        foreach my $line ( @prescript ) {
            if( defined $line ) {
                print $fh $line,"\n";
            }
        }
        print $fh "\n";
    }
    if( @postscript ) {
        print $fh '%post',"\n";
        foreach my $line ( @postscript ) {
            if( defined $line ) {
                print $fh $line,"\n";
            }
        }
        print $fh "\n";
    }
    if( @unprescript ) {
        print $fh '%preun',"\n";
        foreach my $line ( @unprescript ) {
            if( defined $line ) {
                print $fh $line,"\n";
            }
        }
        print $fh "\n";
    }
    if( @unpostscript ) {
        print $fh '%postun',"\n";
        foreach my $line ( @unpostscript ) {
            if( defined $line ) {
                print $fh $line,"\n";
            }
        }
        print $fh "\n";
    }
    print $fh "%files\n";
    print $fh "%defattr(-,root,root)\n";
    print $fh '%attr(-, root, root ) /',"\n";
    $fh->close();
    return $specfile;
}

#sub _specFile {
#    my $self=shift;
#    my $rpm=shift;
#    my $project=shift;
#
#    my $builddir=$self->{fullwork}."/".$rpm."/BUILD";
#    my $specdir=$rpm."/SPECS";
#    my $projname=$self->projectName();
#    my $version=$self->projVersion();
#    my $arch=$self->arch($project);
#    my $desc=$project->summary();
#    if( ! defined $desc || $desc eq "" ) {
#        $desc="Nobody Knows";
#    }
#    my $depends=join(",",$project->dependencies()->platformDependencies($self->{platform},"runtime"));
#    my $provides=join(",",$project->provides());

#    my $fh=RemoteFileHandle->new($self->{platform});
#    my $spec=$projname."-".$version.".spec";
#    my $specfile=$self->{workdir}."/".$specdir."/".$spec;
#    $fh->open(">".$specfile) or die ( "unable to open file $specfile $!\n" );
#    # -- preamble
#    print $fh "Name: ", $projname, "\n";
#    print $fh "Version: ", $version, "\n";
#    print $fh "Release: ", $self->{release}, "\n"; # this is rpm package version for re-packaging instances
#    print $fh "License: ", $project->licence(),"\n";
#    print $fh "Vendor: ", $project->vendor(),"\n";
#    print $fh "Summary:", $desc,"\n";
#    print $fh "Group: ", $project->group(), "\n";
#    print $fh "URL: ", $self->{config}->var("project","url"),"\n", if ( defined $self->{config}->var("project","url") );
#    my $packager= $self->{config}->var("project","packager");
#    print $fh "Packager: $packager\n", if ( defined $packager );
#    print $fh 'BuildRoot: %{_builddir}/%{name}-root',"\n";
#    #$self->setEnv("prefix",'$RPM_BUILD_ROOT');
#    my $workspace=$builddir."/$projname-$version-workspace";
#    $self->setEnv("prefix",$workspace);
#    print $fh "Source: ", $self->{srcPack}, "\n";
#    print $fh "Requires:", $depends, "\n", if( defined $depends && $depends ne "" );
#    print $fh "Provides:", $provides, "\n", if( defined $provides && $provides ne "" );
#    print $fh "%description\n";
#    foreach my $line ( $self->{project}->description() ) {
#        print $fh "    ",$line,"\n";
#    }
#
#    # -- the prep - handled by mpp
#    print $fh "%prep\n%setup -n ", $project->srcDir(), "\n";
#
#    # -- the build
#    #my $cmd=$self->buildInfo("cmd");
#    print $fh "%build\n";
#    foreach my $cmd ( $self->{builder}->buildCommands() ) {
#        print $fh $cmd."\n", if defined ( $cmd );
#    }
#
#    print $fh "%install\n";
#    for ( ($self->{builder}->installCommands()) ) {
#        print $fh $_,"\n";
#    }
    # -- copy our files into the build area
#    foreach my $sub ( $project, $project->subpackages() ) {
        
#    }
    #my $fileHash={};
    #$self->contentIterator("files", \&_copyFiles, $fh, $fileHash );
    #$self->contentIterator("links", \&_linkFiles, $fh, $fileHash );
#    my $files={};
#    foreach my $sub ( $project->subpackages() ) {
#        $self->contentIteratorProject($sub, "files", \&_copyFiles, $fh, $files->{$sub->name()}={} );
#        $self->contentIteratorProject($sub, "links", \&_linkFiles, $fh, $files->{$sub->name()} );
#    }
#    print $fh $self->{platform}->remoteSubroutineCommand("cleanLinks"),' $RPM_BUILD_ROOT',"\n";
    #
    # -- generate the files section
#    my $fileList=$builddir."/fileList";
#    print $fh $self->{platform}->remoteSubroutineCommand("rpmFiles")," -f $fileList ",'$RPM_BUILD_ROOT', 
#                                 join(" ",$project->excludeFiles($self->{platform})), "\n";
#    print $fh "%files -f $fileList\n";
#    print $fh "%defattr(-,root,root)\n";
#    foreach my $dir ( $self->{project}->contents($self->{platform})->dirs() ) {
#        print $fh "%dir $dir\n";
#    }
    #foreach my $f ( keys %{$fileHash} ) {
    #    print $fh "%attr(-, root, root ) ",$fileHash->{$f},"\n";
    #}
    #foreach my $file ( keys %{$fileHash} ) {
    #    print "%attr(-, root, root ) ", $fileHash->{$file} ,"\n";
    #    print $fh "%attr(-, root, root ) ", $fileHash->{$file} ,"\n";
    #}
    #print $fh '%attr(-, root, root ) /',"\n";

    # -- subpackages
#    foreach my $sub ( $self->{project}->subpackages() ) {
#        print $fh "%package -n ", $sub->name(),"\n";
#        print $fh "Summary: ", $sub->summary(),"\n";
#        print $fh "Group: ", $sub->group(),"\n";
#        print $fh "%files -n ",$sub->name(),"\n";
#        foreach my $dir ( $sub->contents($self->{platform})->dirs() ) {
#            print $fh "%dir $dir\n";
#        }
#        foreach my $f ( keys %{$files->{$sub->name()}} ) {
#            print $fh "%attr(-, root, root ) ",$files->{$sub->name()}{$f},"\n";
#        }
#        print $fh "%description -n ", $sub->name(),"\n";
#        foreach my $line ( $sub->description() ) {
#            print $fh "    ",$line,"\n";
#        }
#    }
#    $fh->close();
    #
    #return $specdir."/".$spec;
#}

sub _buildStructure {
    my $self=shift;
    my $dir=shift;
    my $fh=shift;
    my $base=shift;

    my $cmd=$self->{platform}->getMkdirCommand($base.$dir );
    print $fh $cmd,"\n", if ( defined $cmd );
}

sub _copyFiles {
    my $self=shift;
    my $type=shift;
    my $src=shift;
    my $loc=shift;
    my $fh=shift;
    my $fileHash=shift;

    if( defined $loc && defined $src )
    {
        my $prefix=((defined $self->{fileTypePre}{$type})?($self->{fileTypePre}{$type}):"");
        if( $src=~/\*/ ) {
            my $tmp=$loc."/".(basename($src));
            $fileHash->{$tmp}=$prefix.$tmp;
        }
        else {
            $fileHash->{$loc}=$prefix.$loc;
        }
        $src=$self->expandVars($src);
        my $cmd=$self->{platform}->getCopyCommand($src, '$RPM_BUILD_ROOT'.$loc );
        print $fh $cmd,"\n", if ( defined $cmd );
    }
}

sub _linkFiles {
    my $self=shift;
    my $type=shift;
    my $src=shift;
    my $link=shift;
    my $fh=shift;
    my $fileHash=shift;

    if( defined $link && defined $src )
    {
        my $prefix=((defined $self->{fileTypePre}{$type})?($self->{fileTypePre}{$type}):"");
        $fileHash->{$link}=$prefix.$link;
        my $cmd=$self->{platform}->getLinkCommand($src, '$RPM_BUILD_ROOT'.$link );
        print $fh $cmd."\n", if ( defined $cmd );
    }
}


