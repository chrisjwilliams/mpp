# ----------------------------------
# class BuildInfoMPP
# Description:
#   Encapsulation of the build process for running on remote platform
#-----------------------------------
# Methods:
# new() :
# setupCommands() : return a list of commands to create the build structure
# buildCommands() : return a list of the required build commands
# installCommands() : return a list of the installation commands
# dir(subpackage_name) : return the build directory of the given subpackage
#-----------------------------------

package BuildInfoMPP;
use strict;
use ProjectInfo;
use Environment;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{project}=shift; # the ProjectInfo object
    $self->{platform}=shift;
    $self->{workdir}=shift;
    $self->{buildcmd}=shift; # defunct
    my $src=$self->{project}->srcDir();
    $self->{srcDir}=$self->{platform}->workDir()."/".$self->{workdir}.((defined $src)?"/".$src:"");
    $self->{typesLocations}=$self->{platform}->locations();

    # -- set up build variables
    $self->{env}{prefix}=$self->{platform}->workDir()."/".$self->{workdir}."/mpp_build";
    $self->{env}{srcdir}=$self->{srcDir};
    $self->{env}{testdir}=$self->{platform}->workDir()."/".$self->{workdir}."/mpp_test";
    $self->{envobj}=Environment->new( $self->{env} );
    $self->{envobj}->merge($self->sectionEnvironment("build"));
    $self->{envobj}->namespace("build","");
    $self->{locenv}=Environment->new( $self->{typesLocations} );
    $self->{locenv}->namespace("install");

    return $self;
}

sub cleanCommands {
    my $self=shift;
    my $project=shift;
    my @cmds=();
    if( ! defined $project ) {
       $project=$self->{project};
    }
    my $platform=$self->{platform};
    if( $project == $self->{project} ) {
        push @cmds, $platform->getRmdirCommand($self->{env}{prefix});
        my $insdir=$self->{platform}->workDir()."/".$self->{workdir}."/__mpp/mpp_install";
        push @cmds, $platform->getRmdirCommand($insdir);
    }
    return @cmds;
}

sub setupCommands {
    my $self=shift;
    my $project=shift;

    my @cmds=();
    if( ! defined $project ) {
       $project=$self->{project};
    }
    my $platform=$self->{platform};

    if( $project == $self->{project} ) {
        # -- create the overall build structure
        push @cmds, $platform->getMkdirCommand($self->{env}{prefix});
        foreach my $dir ( $project->installDirs($self->{platform}) ) {
            push @cmds, $platform->getMkdirCommand($self->{env}{prefix}.$dir);
        }
        my $insdir=$self->{platform}->workDir()."/".$self->{workdir}."/__mpp/mpp_install";
        push @cmds, $platform->getMkdirCommand($insdir);
    }
    # -- project specific directories
    foreach my $d ( $project, $project->subpackages() ) 
    {
        my $sdir=$self->{platform}->workDir()."/".$self->{workdir}."/".$self->dir($d->name());
        push @cmds, $platform->getMkdirCommand($sdir);
        foreach my $dir ( $d->contents($self->{platform})->dirs() ) {
            push @cmds, $platform->getMkdirCommand($sdir.$dir);
        }
    }
    return @cmds;
}

sub installDir {
    my $self=shift;
    return $self->{env}{prefix};
}

sub dir {
    my $self=shift;
    my $name=shift;
    if( ! defined $self->{dirs}{$name} ) {
        $self->{dirs}{$name}="__mpp/mpp_install/$name";
    }
    return $self->{dirs}{$name};
}

sub buildCommands {
    my $self=shift;
    if(! defined $self->{cleanlinks} ) {
        $self->{cleanlinks}=$self->{platform}->remoteSubroutineCommand("cleanLinks");
    }
    my @cmds=$self->{cleanlinks}." ".$self->{env}{prefix};;
    my $cmd=$self->buildInfo("cmd");
    unshift( @cmds, $cmd ), if( defined $cmd );
    return @cmds;
    #return ($self->buildInfo("cmd"), $self->{cleanlinks}." ".$self->{env}{prefix});
}

sub installCommands {
    my $self=shift;
    my $project=shift;
    if( ! defined $project ) {
       $project=$self->{project};
    }
    my @cmds=();
    foreach my $sub ( $project, $project->subpackages() ) {
        push @cmds, $self->installCommandsProject($sub);
    }
    return @cmds;
}

sub preInstallCommands {
    my $self=shift;
    return $self->sectionForPlatform("preinstall");
}

sub postInstallCommands {
    my $self=shift;
    return $self->sectionForPlatform("postinstall");
}

sub preUninstallCommands {
    my $self=shift;
    return $self->sectionForPlatform("preuninstall");
}

sub postUninstallCommands {
    my $self=shift;
    return $self->sectionForPlatform("postuninstall");
}

# just the project (not subpackages) install commands
sub installCommandsProject {
    my $self=shift;
    my $project=shift;
    if( ! defined $project ) {
       $project=$self->{project};
    }
    my $platform=$self->{platform};

    my @cmds=();
    my $dir=$self->{platform}->workDir()."/".$self->{workdir}."/".$self->dir($project->name());
    push @cmds,$self->_contentIteratorProject( $project,"files", \&_installBuild, $dir );
    push @cmds,$self->_contentIteratorProject( $project,"links", \&_installLink, $dir );
    return @cmds;
}

sub expandVars {
    my $self=shift;
    my $string=shift;
    my $mode=shift;

    $mode="build", if( !defined $mode);

    # -- expand any locally defined variables
    $string=$self->{envobj}->expandString($string);

    # -- expand variables from the project info
    $string=$self->{project}->expandVars( $string );

    # -- expand variables from the platform info
    $string=$self->{platform}->expandString( $string );

    # -- expand locations
    $string=$self->{locenv}->expandString($string);
    #foreach my $v ( keys %{$self->{typesLocations}} ) {
    #    my $var="install::$v";
    #    $string=~s/(.*?)\$\{$var\}(.*?)/$1$self->{typesLocations}{$v}$2/g;
    #}

    # -- expand package variables
    $string=$self->{project}->dependencies()->expandVars($string, $self->{platform}, $mode);

    return $string;
}

sub env {
    my $self=shift;
    return $self->{env};
}

sub buildInfo {
    my $self=shift;
    my $name=shift;
    return $self->sectionInfo("build", $name);
}

sub sectionEnvironment {
    my $self=shift;
    my $section=shift;

    my @keys=($section."::".($self->{platform}->name()),
              $section."::".($self->{platform}->platform()),
              $section );
    my $val=$self->{project}->sectionEnvironment(@keys);
    return $val;
}

sub sectionForPlatform {
    my $self=shift;
    my $section=shift;
    my @keys=($section."::".($self->{platform}->name()),
              $section."::".($self->{platform}->platform()),
              $section );
    my @list=$self->{project}->searchSectionList(@keys);
    my @rv=();
    for( @list ) {
        push @rv, $self->expandVars($_);
    }
    return @rv;
}

sub sectionInfo {
    my $self=shift;
    my $section=shift;
    my $name=shift;

    my @keys=($section."::".($self->{platform}->name()),
              $section."::".($self->{platform}->platform()),
              $section );
    my $val=$self->{project}->searchInfo($name,@keys);
    if( defined $val ) {
        $val=$self->expandVars($val);
    }
    return $val;
}

sub patches {
    my $self=shift;
    my $pat1=$self->sectionInfo("code","patches");
    my @patches=();
    if( defined $pat1 ) {
         push @patches,split(/\s*,\s*/, $pat1);
    }
    return @patches;
}

sub _installLink {
    my $self=shift;
    my $type=shift;
    my $target=shift;
    my $dst=shift;
    my $dir=shift;

    #print "linking $dir$dst->$target\n";
    $target=$self->expandVars($target);
    my $cmd=$self->{platform}->getLinkCommand($target , $dir.$dst);
    return (defined $cmd)?$cmd:();
}

sub _installBuild {
    my $self=shift;
    my $type=shift;
    my $file=shift;
    my $dst=shift;
    my $dir=shift;

    $file=$self->expandVars($file);
    if( defined $self->{srcDir} && $file!~/^[\\\/]/) {
        $file=$self->{srcDir}."/".$file;
    }
    my $cmd=$self->{platform}->getCopyCommand($file , $dir.$dst);
    return (defined $cmd)?$cmd:();
}

#
# iterate over the content of files or links of a given projectInfo
# callback is executed with (self, type, srcfile, destination, @other) arguments
#   
sub _contentIteratorProject {
    my $self=shift;
    my $project=shift;
    my $name=shift; # files or links
    my $callback=shift;

    my $content=$project->contents($self->{platform});
    my @cont;
    my @rv=();
    if( $name eq "files" ) {
        @cont=$content->files();
    }
    elsif( $name eq "links" ) {
        @cont=$content->links();
    }
    foreach my $section ( @cont )
    {
        push @rv, $callback->($self, $section->[2], $section->[0], $section->[1], @_);
    }
    return @rv;
}
