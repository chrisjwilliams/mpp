# ----------------------------------------
#
# Unit test for the Project Class
#
# ----------------------------------------
#

package test_Project;
use Project;
use ProjectManager;
use File::Path;
use File::Copy;
use File::Sync qw( sync );
use TestUtils::TestPackage;
use TestUtils::MppApi;
use FileHandle;
use DirHandle;
use Archive::Tar;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self,$class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{api}=TestUtils::MppApi->new($self->{testConfigDir}, $self->{tmpdir});
    $self->{platformM}=$self->{api}->getPlatformManager();
    $self->{localhost}=$self->{platformM}->getPlatform("localhost");
    $self->{tpack}=TestUtils::TestPackage->new($self->{testConfigDir},$self->{tmpdir});
    $self->{testPkg}=$self->{tpack}->getPackage("deb");

    # -- create a copy of the project configuration directory
    $self->{configSrcDir}=$self->{testConfigDir}."/test_project";
    my $dh=DirHandle->new($self->{configSrcDir}) or die "unable to open dir ".$self->{configSrcDir};
    my @files=$dh->read();
    foreach my $file ( @files ) {
        next, if( $file=~/^\.+/);
        next, if( ! -f $self->{configSrcDir}."/".$file );
        copy($self->{configSrcDir}."/".$file, $self->{tmpdir}."/".$file );
    }

    # -- create a tar archive
    $self->{tar}=$self->{tpack}->tar();

    $self->{name}="testProject";
    $self->{version}="testVersion";
    return $self;
}

sub tests
{
    return qw(test_platforms test_setPlatforms test_build test_variant test_test);
    return qw(test_platforms test_setPlatforms test_buildfailed test_build test_variant test_test);
}

sub test_buildfail {
    my $self=shift;
    my $project=$self->_newProjectObject("buildfail.ini");
    $project->build();
    $project->buildFailed() ne 0, or die "expecting build to return fail";
}

sub test_variant {
    my $self=shift;
    my $project=$self->_newProjectObject("install-variants.ini");
    $project->build();
    my @expectedpkgs=qw(variant1a-defined_build test_project-variant1-variant1c_build);
    my $dir=$project->_localwork($self->{localhost});
    foreach my $pkg ( @expectedpkgs ) {
        my $file=$dir."/".$pkg.".testpkg";
        die("expecting to find package file $file"), if ( ! -f $file );
    }
    my $pkg1a=INIConfig->new( $dir."/variant1a-defined_build.testpkg");
    my $pkg1c=INIConfig->new( $dir."/test_project-variant1-variant1c_build.testpkg");
    die( "variant1a build command not run" ), if( ! defined $pkg1a->var("process", "cmd") );
    die( "variant1c build command not run" ), if( ! defined $pkg1c->var("process", "cmd") );

    $project->buildFailed() eq 0, or die "build returned fail";
}

sub test_platforms {
    my $self=shift;
    my $project=$self->_newProjectObject();
    my @platforms=$project->platforms();
    die "unexpected platforms returned : @platforms", if ( $#platforms != 0 && $platforms[0] ne "localhost" );
}

sub test_setPlatforms {
    my $self=shift;
    my $project=$self->_newProjectObject();
    my @plats=qw(tplat1 tplat2);
    $project->setPlatforms( @plats );
    my @pobjs=$project->{config}->list("platforms")
}

sub test_build {
    my $self=shift;
    my $project=$self->_newProjectObject();
    $project->build();
    $project->buildFailed() eq 0, or die "build returned fail";
    sync();
}

sub test_test {
    my $self=shift;
    # -- 
    my $project=$self->_newProjectObject();
    $project->test();
}

sub _newProjectObject {
    my $self=shift;
    my $configfile=shift;
    if( ! defined $configfile ) {
        $configfile="install.ini";
    }
    my $dir=$self->{tmpdir};
    my $config=INIConfig->new($self->{testConfigDir}."/test_project/".$configfile);
    $config->setVar("code","srcPack",$self->{tar});
    my $copyFile1 = $self->{tmpdir}."/copyFile1";
    die "tmpdir has gone!", if ( ! -d $self->{tmpdir} );
    $config->setVar("build","copy","copyFile1 copyFile_a");
    my $fh=FileHandle->new(">".$copyFile1) or die "_newProjectObject : unable to create $copyFile1 : $!";
    print $fh "# Some file\n";
    $fh->close();
    my $pinfo=ProjectInfo->new($config, $dir, $self->{name}, $self->{version}  );
    my $project=Project->new($config, $self->{api}, $pinfo );
    return $project;
}
