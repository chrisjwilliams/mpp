# -----------------------------------------------
# Debian
# -----------------------------------------------
# Description: 
# Create Debian Packages
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new(Platform, workspace_name, INIConfig) : new object
#
#

package Packagers::Debian;
use strict;
use Packagers::Packager;
use RemoteFileHandle;
use Manglers::DigitsFirst;
use Manglers::ReplaceNonAlphaNumeric;
our @ISA=qw(Packagers::Packager);
1;

# -- initialisation

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    #$self->{platform}=shift;
    #$self->{workdir}=shift;
    #$self->{config}=shift;
    #$self->{project}=shift;
    $self->{suffix}="deb";

    # -- type locations
    #$self->{typesLocations}=$self->{platform}->locations();

    # default version mangler
    my $mangler=new Manglers::ReplaceNonAlphaNumeric;
    $mangler->addMangler(new Manglers::DigitsFirst);
    $self->setVersionMangler($mangler);

    # -- calculate locations
    $self->{srcDir}=$self->{project}->srcDir();
    return $self;
}

sub packageFiles {
    my $self=shift;
    my @packages=($self->_packageFile($self->{project}));
    foreach my $p ( $self->{project}->subpackages() ) {
        push @packages, $self->_packageFile($p);
    }
    return @packages;
}

sub projectName {
    my $self=shift;
    (my $projname=$self->SUPER::projectName())=~s/_/-/g;
    return $projname;
}

#sub projectVersion {
#    my $self=shift;
    # _ is not allowed
#    (my $version=$self->SUPER::projectVersion())=~s/_/-/g;
    # -- must start with a digit 
    #$version=~s/^(\D+)(.*)/0.$2$1/; # if starts with anything else, 
                                   # then move word to end of the version string
                                   # and insert a 0. before it
#    return $version;
#}

sub setup {
    my $self=shift;
    my $downloadDir=shift;
    my $log=shift;

    my $project=$self->{project};

    # invoke the setup commands
    $self->runCommands( $log, $self->{builder}->cleanCommands() );
    $self->runCommands( $log, $self->{builder}->setupCommands() );
    foreach my $d ( $project, $project->subpackages() ) 
    {
        # install debian package files in each subproject directory
        $self->_prepareDir( $self->srcDir(), $d );
    }

    # -- set expansion variables
    #$self->{env}{prefix}=$self->{platform}->workDir()."/".$self->{workdir}."/debian";

    # -- install essential packages
    $self->{platform}->installPackages($log, "fakeroot", "dpkg-dev");
}

sub dependencies {
    return ( { name=>'fakeroot' }, { name=>'dpkg-dev' } );
}

sub build {
    my $self=shift;
    my $downloadDir=shift;
    my $log=shift;

    my $project=$self->{project};
    my $srcDir=$self->{srcDir};

    my $rv=0;
    $self->setup($downloadDir, $log);

    if( ! $self->{config}->itemExists("options","no_build") ) {
       my @cmds=$self->{builder}->buildCommands();
       if( @cmds )
       {
           my $cmd="cd $srcDir && ".(join "&&", @cmds), if ( defined $srcDir && $srcDir ne "" );
           print $log "Building......\n";
           $rv=$self->remote($log,$cmd); 
       }
    }

    # -- copy explicit files into the debian tree
    print $log "Copying Files...\n";
    $self->runCommands( $log, $self->{builder}->installCommands() );

    foreach my $sub ( $project, $project->subpackages() ) {
        my $deb=$self->{builder}->dir($sub->name());
    #    $self->contentIteratorProject( $sub,"files", \&_installBuild, $deb );
    #    $self->contentIteratorProject( $sub,"links", \&_installLink, $deb );
        $self->cleanLinks($deb, $log);
        $self->_control($sub, $deb, $log);
        my $name=$self->_packageFile($sub);
        print $log "Creating deb package ", $name," in $deb\n";
        $self->remote($log, "fakeroot dpkg-deb --build $deb ".($name) );
    }

    print $self->{platform}->hostname(), "> Storing deb packages...\n";
    $self->{platform}->download( $self->{workdir}, $downloadDir, $self->packageFiles() );
    return $rv;
}



sub _prepareDir {
    my $self=shift;
    my $srcDir=shift; # relative to workdir
    my $proj=shift;

    my $workDir=$self->{workdir};
    my $name=$proj->name($self->{platform});
    #my $deb="debian_$name";
    my $deb=$self->{builder}->dir($name);
    my $DEB=$deb."/DEBIAN";

    # -- Create the install tree if defined in the config
    $self->{platform}->mkdir( $workDir, $DEB );
    foreach my $d ( ($proj->contents($self->{platform})->dirs()) ) {
        $self->{platform}->mkdir( $self->{workdir}, $deb.$d );
    }

    # -- create the debian rules file
    my $rules=$DEB."/rules";
    my $fh=RemoteFileHandle->new($self->{platform});
    $fh->open(">".$workDir."/".$rules) or die ( "unable to open file $rules $!\n" );
    print $fh "#\n";
    $fh->close() or die ( "problems writing file $!\n" );

    return $deb;
}

sub _control {
    my $self=shift;
    my $project=shift;
    my $deb=shift;
    my $log=shift;
    my $DEB=$deb."/DEBIAN";
    my $control=$DEB."/control";
    my $workDir=$self->{workdir};

    # -- create the debian control file
    my $projname=$self->SUPER::projectName(); #$project->name($self->{platform});
    $projname=~s/_/-/g;
    my $version=$self->projectVersion();
    my $depends=PackageInfo::standardNames("runtime",$project->dependencies()->platformDependencies($self->{platform},"runtime"));
    my $optionaldepends=PackageInfo::standardNames("runtime",$project->dependencies()->platformDependencies($self->{platform},"optional"));
    my $conflicts=$project->conflicts();
    my $replaces=$project->replaces();
    my $arch=$self->arch();
    my $size=$self->_size($deb, $log, "DEBIAN");
    { use integer; $size=$size/1024, if( $size != 0 ); }
    $depends = "", if( ! defined $depends );
    my $fh=RemoteFileHandle->new($self->{platform});
    $fh->open(">".$workDir."/".$control) or die ( "unable to open file $control $!\n" );
    print $fh "Package: ", $projname, "\n",
              "Version: ", $version, "\n",
              "Source: ", $projname, "\n",
              "Maintainer: christopher.williams\@oerc.ox.ac.uk\n",
              "Section: unknown\n",
              "Priority: optional\n",
              "Architecture: $arch\n",
              "Installed-Size: ", $size ,"\n";
    print $fh "Depends: ", $depends,"\n", if( defined $depends && $depends ne "" );
    print $fh "Conflicts: ", $conflicts,"\n", if( defined $conflicts && $conflicts ne "" );
    print $fh "Replaces: ", $replaces,"\n", if( defined $replaces && $replaces ne "" );
    #print $fh "Optional: ", $optionaldepends,"\n", if( defined $optionaldepends && $optionaldepends ne "" );
    my $desc=$self->{config}->var("project","description");
    if( ! defined $desc || $desc eq "" ) {
        die("no description field given");
        #$desc="Nobody Knows";
    }
    print $fh "Description: ", $desc, "\n";
    $fh->close() or die ( "problems writing file $!\n" );

    # postinstall and uninstall files
    my @seperateSharedDir=$project->extraLibraryDirs();
    my @prescript=$self->{builder}->preInstallCommands();
    my @postscript=$self->{builder}->postInstallCommands();
    my @unprescript=$self->{builder}->preUninstallCommands();
    my @unpostscript=$self->{builder}->postUninstallCommands();

    # pre-install file
    my $preinstfile=$DEB."/preinst";
    if( $#prescript >= 0 ) {
        $fh->open(">".$workDir."/".$preinstfile) or die ( "unable to open file $preinstfile $?\n" );
        $fh->setPermissions(0755);
        print $fh "#!/bin/bash\nset -e\n";
        foreach my $line ( @prescript ) {
            if( defined $line ) {
                print $fh $line,"\n";
            }
        }
        $fh->close();
    }

    # post-install file
    if( $#seperateSharedDir >= 0  ) {
        push @postscript, "/sbin/ldconfig";
        push @unpostscript, "/sbin/ldconfig";
    }
    my $postinstfile=$DEB."/postinst";
    if( $#postscript >= 0 ) {
        $fh->open(">".$workDir."/".$postinstfile) or die ( "unable to open file $postinstfile $!\n" );
        $fh->setPermissions(0755);
        print $fh "#!/bin/bash\nset -e\n";
        foreach my $line ( @postscript ) {
            print $fh $line,"\n";
        }
        $fh->close();
    }

    # preuninstall file
    my $preuninstfile=$DEB."/prerm";
    if( $#unprescript >= 0 ) {
        $fh->open(">".$workDir."/".$preuninstfile) or die ( "unable to open file $preuninstfile $?\n" );
        $fh->setPermissions(0755);
        print $fh "#!/bin/bash\nset -e\n";
        foreach my $line ( @unprescript ) {
            if( defined $line ) {
                print $fh $line,"\n";
            }
        }
        $fh->close();
    }

    # postuninstall file
    my $postuninstfile=$DEB."/postrm";
    if( $#unpostscript >= 0 ) {
        $fh->open(">".$workDir."/".$postuninstfile) or die ( "unable to open file $postuninstfile $?\n" );
        $fh->setPermissions(0755);
        print $fh "#!/bin/bash\nset -e\n";
        foreach my $line ( @unpostscript ) {
            if( defined $line ) {
                print $fh $line,"\n";
            }
        }
        $fh->close();
    }

}

sub _packageFile {
    my $self=shift;
    my $proj=shift;
    my $packageName=($proj->name($self->{platform}))."-".($self->projectVersion()).".deb";
    return $packageName;
}
