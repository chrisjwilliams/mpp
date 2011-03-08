# ----------------------------------
# class test_BuildInfoMPP
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_BuildInfoMPP;
use strict;
use BuildInfoMPP;
use TestUtils::MppApi;
use File::Copy;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{api}=TestUtils::MppApi->new( $self->{testConfigDir}, $self->{tmpdir} );
    $self->{platformM}=$self->{api}->getPlatformManager();
    $self->{localhost}=$self->{platformM}->getPlatform("localhost");
    die( "Error initilising localhost platform" ), if ! defined $self->{localhost};

    # -- create a copy of the project configuration directory
    $self->{configSrcDir}=$self->{testConfigDir}."/test_project";
    my $dh=DirHandle->new($self->{configSrcDir}) or die "unable to open dir ".$self->{configSrcDir};
    my @files=$dh->read();
    foreach my $file ( @files ) {
        next, if( $file=~/^\.+/);
        next, if( ! -f $self->{configSrcDir}."/".$file );
        copy($self->{configSrcDir}."/".$file, $self->{tmpdir}."/".$file );
    }

    return $self;
}

sub tests {
    return qw( test_setup test_setup_subpackages test_build test_install);
}

sub test_setup {
    my $self=shift;
    my $info=$self->_setup();
    my @scmd=sort($info->setupCommands());
    my @escmd=sort(
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp_build",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp_build/usr",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp_build/usr/bin",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp_build/usr/bin/subbin",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp_build/usr/include",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp_build/usr/lib",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp_install",
               "mkdir -p $self->{tmpdir}/localhost/workspace/__mpp/mpp_install/test_project",
               "mkdir -p $self->{tmpdir}/localhost/workspace/__mpp/mpp_install/test_project/usr",
               "mkdir -p $self->{tmpdir}/localhost/workspace/__mpp/mpp_install/test_project/usr/bin",
               "mkdir -p $self->{tmpdir}/localhost/workspace/__mpp/mpp_install/test_project/usr/bin/subbin",
               "mkdir -p $self->{tmpdir}/localhost/workspace/__mpp/mpp_install/test_project/usr/include",
               "mkdir -p $self->{tmpdir}/localhost/workspace/__mpp/mpp_install/test_project/usr/lib");
    die("got   \t'@scmd'\nexpecting\t'@escmd'"), if ("@scmd" ne "@escmd" );

    my $install=$info->installDir();
    my $expect=$self->{localhost}->workDir()."/workspace/mpp/mpp_build";
    die("expecting $expect, got $install"), if( $expect ne $install);

    my $dir=$info->dir("test_project");
    my $expdir="mpp/mpp_install/test_project";
    die("expecting $expdir, got $dir"), if( $expdir ne $dir);
}

sub test_build {
    my $self=shift;
    {
        my $info=$self->_setup();
        my ($cmd)=$info->buildCommands();
        my $expect="./make_testproject";
        die("expecting $expect, got $cmd"), if( $expect ne $cmd);
    }
    {
        my $info=$self->_setup("install-subpackages.ini");
        my ($cmd)=$info->buildCommands();
        my $expect="./make_testproject $self->{tmpdir}/localhost/workspace/mpp/mpp_build";
        die("expecting $expect, got $cmd"), if( $expect ne $cmd);
    }
}

sub test_install {
    my $self=shift;
    my $info=$self->_setup();
    my @icmd=sort($info->installCommands());
    my $work=$self->{tmpdir}."/localhost/workspace/src";
    my $base=$self->{tmpdir}."/localhost/workspace/mpp/mpp_install";
    my $copy="cp -r";
    my $link="sudo ln -f -s";
    my @eicmd=sort("$copy $work/../build_clean/*.h $base/test_project/usr/include",
                   "$copy $work/../build_clean/*.a $base/test_project/usr/lib",
                   "$copy $work/../build_clean/*.so $base/test_project/usr/lib",
                   "$copy $work/build_dirty/*.h $base/test_project/usr/include",
                   "$copy $work/build_dirty/*.a $base/test_project/usr/lib",
                   "$copy $work/build_dirty/*.so $base/test_project/usr/lib",
                   "$copy $work/hello.pl $base/test_project/usr/bin/hello.pl",
                   "$copy $work/hello.pl $base/test_project/usr/bin/subbin/hello.pl",
                   "$link lib1.so $base/test_project/usr/lib/lib1.so.0",
                   "$link lib2.so $base/test_project/usr/lib/lib2.so.0",
                   "$link lib3.so $base/test_project/usr/lib/lib3.so.0",
                   "$link lib4.so $base/test_project/usr/lib/lib4.so.0",
                   "$link lib3.a $base/test_project/usr/lib/lib3.a.0",
                   "$link lib5.a $base/test_project/usr/lib/lib5.a.0",
                  );
    die("got   \t'@icmd'\nexpecting\t'@eicmd'"), if ("@icmd" ne "@eicmd" );
}

sub test_setup_subpackages {
    my $self=shift;
    my $info=$self->_setup("install-subpackages.ini");
    my @scmd=sort($info->setupCommands());
    my @escmd=sort("mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_build",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_build/usr",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_build/usr/bin",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_build/usr/bin/subbin",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_build/usr/lib",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_install",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_install/test_project-sub",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_install/test_project-sub/usr",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_install/test_project-sub/usr/bin",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_install/test_project-sub/usr/bin/subbin",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_install/test_project-sub-variant2",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_install/test_project-sub-variant2/usr",
               "mkdir -p $self->{tmpdir}/localhost/workspace/mpp/mpp_install/test_project-sub-variant2/usr/lib"
           );
    die("got   \t'@scmd'\nexpecting\t'@escmd'"), if ("@scmd" ne "@escmd" );

    my $install=$info->installDir();
    my $expect=$self->{localhost}->workDir()."/workspace/mpp/mpp_build";
    die("expecting $expect, got $install"), if( $expect ne $install);
}

sub _setup {
    my $self=shift;
    my $ini=shift;
    if( ! defined $ini ) {
        $ini="install.ini";
    }
    my $dir=$self->{tmpdir};
    my $config=INIConfig->new($self->{testConfigDir}."/test_project/$ini");
    my $pinfo=ProjectInfo->new($config, $dir,"testProject", "testVersion"  );
    my $binfo=BuildInfoMPP->new($pinfo,$self->{localhost}, "workspace", "buildcmd");
    return $binfo;
}
