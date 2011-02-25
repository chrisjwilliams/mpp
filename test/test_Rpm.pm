# ----------------------------------------
#
# Unit test for the Packagers Rpm Class
#
# ----------------------------------------
#

package test_Rpm;
use Packagers::Rpm;
use TestUtils::TestPackager;
use INIConfig;
use ProjectInfo;
use Package::Rpm;
use File::Sync qw(sync);
use strict;
our @ISA = qw(TestUtils::TestPackager);
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self,$class;
    return $self;
}

sub tests
{
    return qw(test_prepareDir test_buildPackage test_subPackage);
}

sub test_prepareDir {
    my $self=shift;
    # whitebox test to check the initial structure is there

    my ( $src, $work, $pack, $config ) = $self->_setup();
    $pack->_prepareDir();
    sync();

    # -- check the rpm structure
    my $rpm=$work."/rpm";
    my $build=$rpm."/BUILD";
    my $specs=$rpm."/SPECS";
    my $srcs=$rpm."/SOURCES";
    my $rpms=$rpm."/RPMS";
    my $srpms=$rpm."/SRPMS";
    die "topdir $rpm does not exist", if( ! -d $rpm );
    die "SPECS  ($specs) does not exist", if( ! -d $specs );
    die "BUILD ($build) does not exist", if( ! -d $build );
    die "RPMS  ($rpms) does not exist", if( ! -d $rpms );
    die "SRPMS  ($srpms) does not exist", if( ! -d $srpms );
    die "SOURCES  ($srcs) does not exist", if( ! -d $srcs );
}

sub test_buildPackage {
    my $self=shift;

    my ( $src, $work, $pack, $config , $log ) = $self->_setup();
    my $rpm=$work."/mpp_install/test_project";
    my $bin=$rpm."/usr/bin";
    my $lib=$rpm."/usr/lib";
    my $include=$rpm."/usr/include";

    $pack->build($self->{tmpdir}, $log);
    sync();

    # - check the installed components in the rpm tree
    my @includes=qw(include1.h include2.h include1.h include2.h);
    foreach my $b ( @includes )
    {
        my $file=$include."/".$b;
        die $file." not found", if ! -f $file;
    }
    my @bins=qw(hello.pl subbin/hello.pl );
    foreach my $b ( @bins )
    {
        my $file=$bin."/".$b;
        die $file." not found", if ! -f $file;
    }
    my @libs=qw(lib1.so lib2.so lib3.a lib3.so lib4.so lib5.a);
    foreach my $b ( @libs )
    {
        my $file=$lib."/".$b;
        my $link=$file.".0";
        die $file." not found", if ! -f $file;
        die $link." link not found", if ! -l $link;
    }

    # - check the _size returns something
    #my $size=$pack->_size();
    #die "size returned $size", if( $size <= 0 );

    # - check the package files exist on the host
    my $arch=$self->{localhost}->arch();
    my $packageroot="test_project-1.2.3-1";
    my $packagename=$packageroot.".$arch.rpm";

    my $rpms=$work."/rpm/RPMS/$arch";
    if( ! -f $rpms."/".$packagename ) {
        print $pack->remote("ls $rpms");
        die "$packagename does not exist on host ($rpms)";
    }
    my $packagesrc=$packageroot.".src.rpm";
    my $srpms=$work."/rpm/SRPMS";
    if( ! -f $srpms."/".$packagesrc ) {
        print $pack->remote("ls $srpms");
        die "$packagesrc does not exist on host ($srpms)";
    }

    # - check the package files are returned from the host
    if( ! -f $self->{tmpdir}."/".$packagename ) {
        die "$packagename has not been transferred";
    }
    die "$packagesrc has not been transferred", if( ! -f $self->{tmpdir}."/".$packagesrc );

    # - check contents of the packges are correct
    {
        my $rpm=Package::Rpm->new($self->{tmpdir}."/test_project-1.2.3-1.$arch.rpm");
        my @rpmcontent=sort($rpm->content());
        my @expectedcontent=sort(qw(/ /usr /usr/bin /usr/include /usr/bin/subbin /usr/lib),@{$self->{expectedcontent}});
        die("contents of test_project-sub-variant2-1.2.3-1.$arch.rpm incorrect. got (@rpmcontent)\n\texpecting (@expectedcontent)"), 
                    if ( "@rpmcontent" ne "@expectedcontent" );
    }

    # - check the build_log exists
    my $logfile=$self->{tmpdir}."/build_log_install.ini";
    die "build_log missing ( $logfile )", if ( ! -f $logfile );
    unlink $logfile; # -- clean up for next test
}

sub test_subPackage {
    my $self=shift;
    my ( $src, $work, $pack, $config , $log ) = $self->_setup("install-subpackages.ini");
    my $rpm=$work."/rpm/BUILD/test_project-root";
    my $bin=$rpm."/usr/bin";
    my $lib=$rpm."/usr/lib";
    my $include=$rpm."/usr/include";

    $pack->build($self->{tmpdir}, $log);
    sync();

    my $arch=$self->{localhost}->arch();
    my @expectedpkgs=qw(test_project-sub test_project-sub-variant2);
    foreach my $pkg ( @expectedpkgs ) {
        my $file=$self->{tmpdir}."/$pkg-1.2.3-1.".$arch.".rpm";
        die("expecting to find package file $file"), if ( ! -f $file );
    }

    # - check contents of the packges are correct
    {
        my $rpm=Package::Rpm->new($self->{tmpdir}."/test_project-sub-variant2-1.2.3-1.$arch.rpm");
        my @rpmcontent=sort($rpm->content());
        my @expectedcontent=(qw(/ /usr /usr/lib),@{$self->{expectedcontent_variant2}});
        die("contents of test_project-sub-variant2-1.2.3-1.$arch.rpm incorrect. got (@rpmcontent)\n\texpecting (@expectedcontent)"), 
                    if ( "@rpmcontent" ne "@expectedcontent" );
    }
    {
        my $rpm=Package::Rpm->new($self->{tmpdir}."/test_project-sub-1.2.3-1.$arch.rpm");
        my @rpmcontent=sort($rpm->content());
        my @expectedcontent=sort(qw(/ /usr/bin/subbin /usr/bin /usr), @{$self->{expectedcontent_sub}});
        die("contents of test_project-sub-1.2.3-1.$arch.rpm incorrect. got (@rpmcontent)\n\texpecting (@expectedcontent)"), 
                    if ( "@rpmcontent" ne "@expectedcontent" );
    }
    # - check the build_log exists
    my $logfile=$self->{tmpdir}."/build_log_install-subpackages.ini";
    die "build_log missing ( $logfile )", if ( ! -f $logfile );
}

sub _setup {
    my $self=shift;
    my $ini=shift;
    if( ! defined $ini ) {
        $ini="install.ini";
    }
    my $config=INIConfig->new($self->{testConfigDir}."/test_project/$ini");
    my $dir=$self->{tmpdir};
    my $pinfo=ProjectInfo->new($config, $dir, "testProject", "testVersion"  );
    my $pack=Packagers::Rpm->new($self->{localhost}, "testProject",$config, $pinfo);
    # -- set up the src tree on the host
    my $work=$self->{localhost}->workDir()."/testProject";
    my $src=$work."/src";
    File::Copy::Recursive::dircopy( $self->{testConfigDir}."/test_project/src", $src );
    my $log=FileHandle->new(">".$self->{tmpdir}."/build_log_$ini");
    #my $log=*STDOUT;

    return ( $src, $work, $pack, $pinfo , $log);
}
