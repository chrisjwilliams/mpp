# ----------------------------------------
#
# Unit test for the Apt Class
#
# ----------------------------------------
#

package test_Apt;
use Publishers::Apt;
use File::Path;
use File::Sync qw( sync );
use TestUtils::TestPackage;
#use File::Copy::Recursive;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self,$class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{tpack}=TestUtils::TestPackage->new($self->{testConfigDir},$self->{tmpdir});
    $self->{testPkg}=$self->{tpack}->getPackage("deb");
    return $self;
}

sub tests
{
    return qw(test_dirStructure test_addNonExisting test_addRemovePackage);
}

sub test_aptDownload {
    my $self=shift;

    my $aptCmd="/usr/bin/apt-get";
    if( -f $aptCmd )
    {
        # download the file from our repository
        my @cmds=( $aptCmd, "--download", $self->{testPkg});
        system(@cmds) 
                or die "Error running $aptCmd : $@";
    }
    else {
        die("apt-get not available");
    }
}

sub test_addNonExisting {
    my $self=shift;

    my $type="testType";
    my $release="stableish";
    my $arch="amd64";

    my $dir=$self->{tmpdir}."/apt";
    my $apt=new Publishers::Apt( { root => $dir } );
    my $pkg=Package::Package->new( {
            name => "testname",
            arch=>$arch,
            platform=>$type }
    );
    $pkg->setFiles($self->{tmpdir}."/notHere.deb");
    eval {
        $apt->add($release, $pkg);
    };
    if($@) {
        return 0;
    }
}

sub test_addRemovePackage {
    my $self=shift;

    my $release="main"; # hardcoded for now
    my $platform="some_platform";
    my $arch="test_arch";

    my $dir=$self->{tmpdir}."/apt";
    my $apt=new Publishers::Apt( { root => $dir } );
    my $pool=$dir."/pool";
    my $rpool=$pool."/".$platform;
    my $tpool=$rpool."/".$release;
    my $dist=$dir."/dists";
    my $rdist=$dist."/".$platform;
    my $rfile=$rdist."/Release";
    my $cfilegz=$rdist."/Contents-$arch.gz";
    my $tdist=$rdist."/".$release;
    my $bindir=$tdist."/binary-$arch";
    my $srcdir=$tdist."/source";
    my $relbin=$bindir."/Release";
    my $packages=$bindir."/Packages.gz";

    my $pkg=Package::Package->new( {
            name => "testname",
            arch=>$arch,
            platform=>$platform }
    );
    $pkg->setFiles($self->{testPkg});

    # add the package and test the full structure exists
    $apt->add($release, $pkg);
    sync();
    die("directory $pool does not exist"), if ( ! -d $pool );
    die("directory dist='$dist' does not exist"), if( ! -d $dist ); 
    die("directory $rdist does not exist"), if( ! -d $rdist );
    die("directory $tdist does not exist"), if( ! -d $tdist );
    die("directory $rpool does not exist"), if( ! -d $rpool );
    die("directory $tpool does not exist"), if( ! -d $tpool );

    die("file $rfile does not exist"), if( ! -f $rfile );
    #die("file $cfilegz does not exist"), if( ! -f $cfilegz );
    die("directory $bindir does not exist"), if( ! -d $bindir );
    die("directory $srcdir does not exist"), if( ! -d $srcdir );
    die("file $relbin does not exist"), if( ! -f $relbin );
    die("file $packages does not exist"), if( ! -f $packages );

    # ------ test the repository info methods -------------
    # -- expect the arch for the added type/release
    {
        my @archs=$apt->architectures($platform);
        die("architectures() method returning $#archs items"), if( $#archs != 0 || $archs[0] ne $arch );
    }
    {
        my @archs=$apt->architectures("rubbish");
        die("architectures() method returning $#archs items"), if( $#archs >= 0 );
    }

    # remove the package - ensure cleanup of empty structures
    #
    $apt->remove($release, $pkg );
    sync();
    die("file $packages exists"), if( -f $packages );
    die("file $relbin exists"), if( -f $relbin );
    die("directory $bindir exists"), if( -d $bindir );
    #die("file $cfilegz exists"), if( -f $cfilegz );
    #die("file $rfile exists"), if( -f $rfile );
    #die("directory $rdist exists"), if( -d $rdist );
    #die("directory $tdist exists"), if( -d $tdist );
    #die("directory $tpool exists"), if( -d $tpool );

    die("directory $pool does not exist"), if ( ! -d $pool );
    die("directory $dist does not exist"), if( ! -d $dist ); 

    return 0;

}

sub test_locate {
    my $self=shift;
    my $dir=$self->{tmpdir}."/apt";
    my $apt=new Publishers::Apt( { root => $dir });
    # locate a non-existing package
    my @files=$apt->locate( { name=>"no_here" } );
    die "@files returned for non-existing project", if ( $#files >=0 );

    # locate an existing package
    my $release="stableish";
    my $arch="test_arch";
    $apt->add($release, $self->{testPkg});
    @files=$apt->locate( { name=>$self->{tpack}->name() } );
    die "unexpected files @files", if ( $#files !=0 );
}

sub test_dirStructure {
    my $self=shift;

    #
    # whitebox test to check the initial structure is there
    #
    my $dir=$self->{tmpdir}."/apt";
    my $apt=new Publishers::Apt( { root => $dir });

    # -- check the apt structure
    my $msg=$dir;
    if( -d $dir )
    {
        return 0;
    }
    die("unexpected error : $msg");
}
