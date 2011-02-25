# ----------------------------------------
#
# Unit test for the Yum Class
#
# ----------------------------------------
#

package test_Yum;
use Publishers::Yum;
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
    $self->{testPkg}=$self->{tpack}->getPackage("rpm");
    return $self;
}

sub tests
{
    #return qw(test_dirStructure test_addNonExisting test_addRemovePackage);
    return qw(test_dirStructure test_addNonExisting test_addRemovePackage test_illegalRoot);
}

sub test_illegalRoot {
    my $self=shift;
    my $dir=$self->{tmpdir}."/../yum";
    eval {
       my $yum=new Publishers::Yum(  { root => $dir } );
    };
    if($@) {
        return 0;
    }
}

sub test_addNonExisting {
    my $self=shift;

    my $type="testType";
    my $release="stableish";
    my $arch="amd64";

    my $pkg=Package::Package->new( {
            name => "testname",
            arch=>$arch,
            platform=>$type }
    );
    $pkg->setFiles($self->{tmpdir}."/notHere.rpm");
    my $dir=$self->{tmpdir}."/yum";
    my $yum=new Publishers::Yum(  { root => $dir } );
    eval {
        $yum->add($release, $pkg);
    };
    if($@) {
        return 0;
    }
    return 1;
}

sub test_addRemovePackage {
    my $self=shift;

    my $release="main"; # hardcoded for now
    my $platform="some_platform";
    my $arch=$self->{tpack}->arch();

    my $dir=$self->{tmpdir}."/yum";
    my $pool=$dir."/$platform/$release";
    my $srcdir=$pool."/".$arch;
    my $yum=new Publishers::Yum( { root => $dir,
                                   verbose => undef } );
    my $meta=$pool."/repodata/repomd.xml";
    (my $packagename=$self->{tpack}->name("rpm"))=~s/\.$arch$//;
    my $pack=$srcdir."/".$packagename.".rpm";

    my $pkg=Package::Package->new( {
            name => "testname",
            arch=>$arch,
            platform=>$platform }
    );
    $pkg->setFiles($self->{testPkg});

    # add the package and test the full structure exists
    $yum->add($release, $pkg);
    sync();
    die("directory $pool does not exist"), if ( ! -d $pool );
    die("directory $srcdir does not exist"), if( ! -d $srcdir );
    die("file $meta does not exist"), if( ! -f $meta );
    die("package $pack does not exist"), if( ! -f $pack );

    # ------ test the repository info methods -------------
    # -- expect the arch for the added type/release
    {
        my @archs=$yum->architectures($platform, $release);
        die("architectures() method returning $#archs items @archs"), if( $#archs != 0 || $archs[0] ne $arch );
    }
    {
        my @archs=$yum->architectures("rubbish");
        die("architectures() method returning $#archs items"), if( $#archs >= 0 );
    }

    # remove the package - ensure cleanup of empty structures
    #
    #$yum->{verbose}=1;
    $yum->remove($release, $pkg );
    sync();
    die("file $meta exists"), if( -f $meta );
    die("package $pack still exists"), if( -f $pack );
    die("directory $srcdir exists"), if( -d $srcdir );
    die("directory $pool exists"), if ( -d $pool );

    return 0;

}

sub test_dirStructure {
    my $self=shift;

    #
    # whitebox test to check the initial structure is there
    #
    my $dir=$self->{tmpdir}."/yum";
    my $yum=new Publishers::Yum(  { root => $dir });

    # -- check the yum structure
    my $msg=$dir;
    if( -d $dir )
    {
        return 0;
    }
    die("unexpected error : $msg");
}
