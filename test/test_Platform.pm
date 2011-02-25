# ----------------------------------
# class test_Platform
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_Platform;
use strict;
use TestUtils::MppApi;
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
    return $self;
}

sub tests {
   return qw( test_platform test_invoke test_remoteSubroutineBad test_remoteSubroutine test_packageNames test_location );
}

sub test_location {
    my $self=shift;

    my $docpath="main/doc/path";
    my $srcpath="main/src/path";
    my $config=INIConfig->new();
    $config->setVar("locations", "doc", $docpath);
    $config->setVar("locations", "src", $srcpath);
    $config->setVar("system","platform", "testPlatform");
    $config->setVar("system","arch", "testArch");

    my $pconfig=INIConfig->new();
    $pconfig->setVar("system","platform", "testPlatform");
    $pconfig->setVar("system","arch", "testArch");
    my $pdocpath="platform/doc/path";
    my $data=File::SearchPath->new( $self->{testConfigDir}."/Platforms/Data" );
    $pconfig->setVar("locations", "doc", $pdocpath);
    {
        # Use case:
        # [locations] defined in main config file
        my $plat=Platform->new($config, "localhost", $data, $self->{api} );
        my $loc=$plat->locations();
        die "expected $docpath got '".($loc->{"doc"})."'", if( $loc->{"doc"} ne $docpath );
        die "expected $srcpath got '".($loc->{"src"})."'", if( $loc->{"src"} ne $srcpath );
    }
    {
        # Use case:
        # [locations] defined in platform config file only
        my $plat=Platform->new($pconfig, "locahost", $data, $self->{api} );
        my $loc=$plat->locations();
        die "expected $pdocpath got '".($loc->{"doc"})."'", if( $loc->{"doc"} ne $pdocpath );
    }
    {
        # Use case:
        # [locations] defined in main config file & platform config
        # expect main values
        my $plat=Platform->new($config, "localhost", $data, $self->{api} );
        my $loc=$plat->locations();
        die "expected $docpath got '".($loc->{"doc"})."'", if( $loc->{"doc"} ne $docpath );
        die "expected $srcpath got '".($loc->{"src"})."'", if( $loc->{"src"} ne $srcpath );
    }
}

sub test_invoke {
    my $self=shift;
    # -- successful command
    eval { 
        $self->{localhost}->invoke("/bin/sh -e -c \"echo I should be OK; exit 0\"");
    };
    die( "not expecting throw : $@" ) , if( $@ );
    # -- unsuccessful command
    eval { 
        $self->{localhost}->invoke("/bin/sh -e -c \"echo I should fail; exit 1\"");
    };
    die( "expecting throw" ) , if( ! $@ );
}

sub test_platform {
    my $self=shift;
    my $p=$self->{localhost}->platform();
    my $ex="testPlatform";
    die "Expecting $ex : got '$p'", if ( $p ne $ex);
}

sub test_remoteSubroutineBad {
    my $self=shift;

    my $testrt;
    my $log=FileHandle->new(">&main::STDOUT");
    eval { 
        $self->{localhost}->remoteSubroutine("", $log, "unknown");
    };
    die( "expecting throw" ) , if( ! $@ );
}

sub test_remoteSubroutine {
    my $self=shift;

    my $testrt="cleanLinks";
    my $log=FileHandle->new(">&main::STDOUT");
    $self->{localhost}->remoteSubroutine("", $log, $testrt);
    my $mpp=$self->{localhost}->workDir()."/mpp";
    # -- check the correct files have been sent over
    die("directory $mpp does not exist"), if( ! -d $mpp );
    my $rdir=$mpp."/Remote";
    die("directory $rdir does not exist"), if( ! -d $rdir );
    my $rbin=$mpp."/bin";
    die("directory $rbin does not exist"), if( ! -d $rbin );
    my $bin=$rbin."/".$testrt;
    die("file $bin does not exist"), if( ! -f $bin );
    my $dep=$mpp."/File/DirIterator.pm";
    die("file $dep does not exist"), if( ! -f $dep );
}

sub test_packageNames {
    my $self=shift;
    my @packages=( { name=>"test_a" }, { name=>"test_b" }, { name=>"test_c++" }, { name=>"not_listed" } );
    my @builddeps=sort($self->{localhost}->packageNames("build", @packages));
    my @buildexpect=sort(qw(test_a_build test_b_build test_c_common not_listed));
    die "expecting (@buildexpect), got (@builddeps)\n", if ( $#builddeps != $#buildexpect );
    my @runtimedeps=sort($self->{localhost}->packageNames("runtime", @packages));
    # test_b has no runtime and so should be excluded
    my @runtimeexpect=sort(qw(test_a_run test_c_common not_listed));
    die "wrong runtime packages returned (got (@runtimedeps) expecting (@runtimeexpect))\n", if ( "@runtimedeps" ne "@runtimeexpect" );
}
