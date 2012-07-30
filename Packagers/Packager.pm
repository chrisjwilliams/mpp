# -----------------------------------------------
# Packager
# -----------------------------------------------
# Description: 
# Default Packager - just build
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new() : new object
# remote() : execute a command on the remote machine
# buildInfo("name") : return the build information corresponding to the tag
# contentIterator( $key,$callback ) : iterate over the contents description of the project
# contentIteratorProject( ProjectInfo, $key,$callback ) : iterate over the contents description of the specified ProjectInfo
# arch(ProjectInfo) : return the arcitecture of the package
# setEnv(name,value) : set the value of a buildInfo variable
# build( downloadDir, FileHandle log ) : dowloadDir is the directory in which to store packages
# setVersionMangler(Mangler);

package Packagers::Packager;
use strict;
use BuildInfoMPP;
use Environment;
1;

# -- initialisation

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{platform}=shift;
    $self->{workdir}=shift;
    $self->{config}=shift;
    $self->{project}=shift;
    $self->{builder}=new BuildInfoMPP($self->{project},
                                      $self->{platform},
                                      $self->{workdir});
    $self->{suffix}="txt";
    $self->{typesLocations}=$self->{platform}->locations();
    foreach my $v ( keys %{$self->{typesLocations}} ) {
        my $var="install::$v";
        $self->{env}{$var}=$self->{typesLocations}{$v};
    }
    return $self;
}

sub patches {
    my $self=shift;
    return $self->{builder}->patches();
}

sub projectName {
    my $self=shift;
    my $pName=$self->buildInfo("packageName");
    if( ! defined $pName ) {
        $pName=$self->{project}->name($self->{platform});
    }
    return $pName;
}

sub projectVersion {
    my $self=shift;
    my $version=$self->unmangledProjectVersion();
    if( defined $self->{vmangler} ) {
        $version=$self->{vmangler}->mangle($version);
    }
    return $version;
}

sub unmangledProjectVersion {
    my $self=shift;
    my $version=$self->buildInfo("packageVersion");
    if( ! defined $version ) {
        $version=$self->{project}->version($self->{platform});
    }
    return $version;
}

sub setVersionMangler {
    my $self=shift;
    $self->{vmangler}=shift;
}

sub packageFiles {
    my $self=shift;
    return $self->projectName();
}

sub buildDependencies {
    my $self=shift;
    return $self->{platform}->packageInfo( $self->dependencies() );
}

sub dependencies {
    return (); # a hash of name and version keys
}

sub name {
    my $self=shift;
    return $self->{config}{name};
}

sub arch {
    my $self=shift;
    my $project=shift;
    if( ! defined $project ) {
        $project=$self->{project};
    }
    my $arch=$project->arch();
    $arch=$self->{platform}->arch() ,if( ! defined $arch );
    return $arch;
}

sub install {
    my $self=shift;
    return;
}

sub setEnv {
    my $self=shift;
    my $var=shift;
    $self->{env}{$var}=shift;
}

sub build {
    my $self=shift;
#    $self->{platform}->work($self->{workdir},"run", @_);
}

sub setup {
    my $self=shift;
    my $downloadDir=shift;
    my $log=shift;
}

sub remote {
    my $self=shift;
    my $log=shift;
    return $self->{platform}->work($self->{workdir},$log,"run",@_);
}

sub runCommands {
    my $self=shift;
    my $log=shift;
    croak("runCommands() first argument should be a FileHandle for logging"), if ( ! $log->isa("GLOB") );
    foreach my $cmd ( @_ ) {
       $self->remote($log,$cmd);
    }
}

sub srcUploadDir {
    my $self=shift;
    return $self->{workdir};
}

sub buildInfo {
    my $self=shift;
    my $name=shift;

    return $self->{builder}->buildInfo($name);
}

sub srcDir {
    my $self=shift;
    if ( ! defined $self->{srcdir} )
    {
        $self->{srcdir}=$self->{project}->srcDir();
        if( ! defined $self->{srcdir} )
        {
           $self->{srcdir}="src";
        }
    }
    return $self->{srcdir};
}

sub contentIterator {
    my $self=shift;
    $self->contentIteratorProject($self->{project}, @_);
}

#
# iterate over the content of files or links of a given projectInfo
# callback is executed with (self, type, srcfile, destination, @other) arguments
#
sub contentIteratorProject {
    my $self=shift;
    my $project=shift;
    my $name=shift; # files or links
    my $callback=shift;

    my $content=$project->contents($self->{platform});
    my @cont;
    if( $name eq "files" ) {
        @cont=$content->files();
    }
    elsif( $name eq "links" ) {
        @cont=$content->links();
    }
    foreach my $section ( @cont )
    {
        $callback->($self, $section->[2], $section->[0], $section->[1], @_);
    }
}

#sub sectionIterator {
#    my $self=shift;
#    my $name=shift;
#    my $callback=shift;
#
#    my $platform=$self->{platform};
#    foreach my $section ( $self->{config}->sections() )
#    {
#        next, if $section!~/^($name)::(.*)/;
#        my $type=$2;
#        $callback->($self, $section, $type, @_);
#    }
#}

sub createInstallDir {
    my $self=shift;
    my $base=shift;

    for ( $self->{project}->installDirs($self->{platform}) ) {
        $self->{platform}->mkdir( $self->{workdir}, $base.$_ );
    }
}

sub cleanLinks {
    my $self=shift;
    my $dir=shift;
    my $log=shift;

    $self->{platform}->remoteSubroutine( $self->{workdir}, $log, "cleanLinks", $dir );
}

sub expandVars {
    my $self=shift;
    my $string=shift;

    # -- expand any locally defined variables
    foreach my $v ( keys %{$self->{env}} ) {
        $string=~s/(.*?)\$\{$v\}(.*?)/$1$self->{env}{$v}$2/g;
    }
    # -- expand variables from the project info
    $string=$self->{project}->expandVars( $string );
    # -- expand variables from the builder
    $string=$self->{builder}->expandVars( $string );

    # -- expand locations
#    foreach my $v ( keys %{$self->{typesLocations}} ) {
#        my $var="install::$v";
#        $string=~s/(.*?)\$\{$var\}(.*?)/$1$self->{typesLocations}{$v}$2/g;
#    }

    return $string;
}

sub env {
    my $self=shift;
    my $e=Environment->new($self->{builder}->env(), $self->{env});
    return $e->env();
}

#
# return the size of a directory on the specified platform
# arguments:
# dir
# log
# @exclude
#
sub _size {
    my $self=shift;
    my $dir=shift;
    my $log=shift;
    my $report=$self->{platform}->remoteSubroutine( $self->{workdir}, $log, "diskUsage", $dir, @_ );
    (my $size)=$report->stdout();
    return $size;
}
