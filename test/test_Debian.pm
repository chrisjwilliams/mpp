# ----------------------------------------
#
# Unit test for the Packagers Debian Class
#
# ----------------------------------------
#

package test_Debian;
use Packagers::Debian;
use TestUtils::TestPackager;
use ProjectInfo;
use INIConfig;
use TestUtils::MppApi;
use File::Path;
use File::Copy;
use File::Copy::Recursive;
use File::Sync qw(sync);
use FileHandle;
use Debian::Package;
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
    return qw(test_prepareDir test_setup test_buildPackage test_subPackage);
}

sub test_setup {
    my $self=shift;

    my ( $src, $work, $pack, $config, $pinfo, $log  ) = $self->_setup();
    $pack->setup("", $log);

    # -- ensure the exapandVars prefix works
    my $string=$pack->expandVars('${name}-${version} "${prefix}"');
    my $dir="mpp/mpp_build";
    my $expectstr="test_project-1.2.3 \"".$work."/$dir\"";
    die ("bad expansion in expandVars: got '$string' expecting '$expectstr')"), if ( $string ne $expectstr );
    # -- ensure the exand works in buildInfo 
    $string=$pack->buildInfo("expandTest");
    die ("bad expansion in buildInfo: got '$string' expecting '$expectstr')"), if ( $string ne $expectstr );
}

sub test_prepareDir {
    my $self=shift;
    # whitebox test to check the initial structure is there

    my ( $src, $work, $pack, $config, $pinfo  ) = $self->_setup();
    my $dir=$pack->_prepareDir("src", $pinfo);
    sync();

    # -- check the debian structure
    #my $deb=$work."/mpp_builddebian_".($pinfo->name());
    my $deb=$work."/".$pack->{builder}->dir($pinfo->name());
    my $DEB=$deb."/DEBIAN";
    my $rules=$DEB."/rules";
    my $msg=$deb;
    if( -d $deb )
    {
        $msg=$DEB;
        if( -d $DEB ) {
            $msg=$rules;
            if( -f $rules )
            {
                my $bin=$deb."/usr/bin";
                $msg=$bin;
                if( -d $bin ) {
                    my $subbin=$deb."/usr/bin/subbin";
                    $msg=$subbin;
                    if( -d $subbin ) {
                        my $lib=$deb."/usr/lib";
                        if( -d $lib ) {
                            my $include=$deb."/usr/include";
                            $msg=$include;
                            if( -d $include ) {
                                rmtree $deb or die( "unable to remove tree $deb : $!" );
                                return 0;
                            }
                        }
                    }
                }
            }
        }
    }
    die("unexpected error : $msg");
}

sub test_buildPackage {
    my $self=shift;

    my ( $src, $work, $pack, $config, $pinfo, $log ) = $self->_setup();
    my $deb=$work."/".$pack->{builder}->dir($pinfo->name());
    my $bin=$deb."/usr/bin";
    my $lib=$deb."/usr/lib";
    my $include=$deb."/usr/include";
    my $packagename="test_project-1.2.3.deb";

    $pack->build($self->{tmpdir}, $log);
    sync();

    # - check the installed components in the debian tree
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
    my $control=$deb."/DEBIAN/control";
    die "control file not existing", if( ! -f $control );

    # - check the _size returns something
    my $size=$pack->_size($deb);
    die "size returned $size", if( $size <= 0 );

    # - check the package files exist on the host
    if( ! -f $work."/".$packagename ) {
        $pack->remote("ls");
        die "$packagename does not exist on host ($work)";
    }

    # - check the package files are returned from the host
    if( ! -f $self->{tmpdir}."/".$packagename ) {
        die "$packagename has not been transferred";
    }

    # - check the build_log exists
    my $logfile=$self->{tmpdir}."/build_log_install.ini";
    die "build_log missing ( $logfile )", if ( ! -f $logfile );
}

sub test_subPackage {
    my $self=shift;
    my ( $src, $work, $pack, $config, $pinfo , $log ) = $self->_setup("install-subpackages.ini");
    
    $pack->build($self->{tmpdir}, $log);

    my $packagename="test_project-sub-1.2.3.deb";
    # - check the package files are returned from the host
    my @pkgs=sort($packagename, "test_project-sub-variant2-1.2.3.deb");
    foreach my $pkg ( @pkgs ) {
      if( ! -f $self->{tmpdir}."/".$pkg ) {
        die "$pkg has not been transferred";
      }
    }
    my @packageFiles=sort($pack->packageFiles());
    die("unexpected packages (@packageFiles)"), if ( "@packageFiles" ne "@pkgs" );

    # -- check the mpp_build dir is populated
    my @bins=qw(/wibble /usr/bin/wibblewibble /usr/wibble2);
    my $base=$pack->{builder}->installDir();
    foreach my $b ( @bins )
    {
        my $file=$base.$b;
        die $file." not found", if ! -f $file;
    }

    # - check contents of the packges are correct
    {
        my $deb=Debian::Package->new($self->{tmpdir}."/test_project-sub-variant2-1.2.3.deb");
        my @debcontent=sort($deb->content());
        my @expectedcontent=(qw(/ /usr/ /usr/lib/),@{$self->{expectedcontent_variant2}});
        die("contents of test_project-sub-variant2-1.2.3.deb incorrect. got (@debcontent)\n\texpecting (@expectedcontent)"), 
                    if ( "@debcontent" ne "@expectedcontent" );
    }
    {
        my $deb=Debian::Package->new($self->{tmpdir}."/test_project-sub-1.2.3.deb");
        my @debcontent=sort($deb->content());
        my @expectedcontent=sort(qw(/ /usr/ /usr/bin/ /usr/bin/subbin/ ), @{$self->{expectedcontent_sub}}); 
        die("contents of test_project-sub-1.2.3.deb incorrect. got (@debcontent)\n\texpecting (@expectedcontent)"), 
                    if ( "@debcontent" ne "@expectedcontent" );
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
    my $dir=$self->{tmpdir};
    my $config=INIConfig->new($self->{testConfigDir}."/test_project/$ini");
    my $pinfo=ProjectInfo->new($config, $dir,"testProject", "testVersion"  );
    my $pack=Packagers::Debian->new($self->{localhost}, "testProject$ini",$config, $pinfo);
    # -- set up the src tree on the host
    my $work=$self->{localhost}->workDir()."/testProject$ini";
    my $src=$work."/src";
    File::Copy::Recursive::dircopy( $self->{testConfigDir}."/test_project/src", $src );
    my $log=FileHandle->new(">".$self->{tmpdir}."/build_log_".$ini);
    #my $log=*STDOUT;

    return ( $src, $work, $pack, $config , $pinfo, $log);
}
