# ----------------------------------
# class test_Mpp
# Description:
# unit testing for Mpp repository
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package test_Mpp;
use TestUtils::MppApi;
use Package::Mpp;
use Publishers::Mpp;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{api}=TestUtils::MppApi->new($self->{testConfigDir}, $self->{tmpdir});
    $self->{platformM}=$self->{api}->getPlatformManager();
    $self->{localhost}=$self->{platformM}->getPlatform("localhost");
    return $self;
}

sub tests {
    return qw( test_repository test_addPackage test_removePackage);
}

sub test_repository {
    my $self=shift;

    my $reporoot=$self->{tmpdir}."/testrepo";
    my $rep=$self->_init();
    croak("root '$reporoot' not created"), if( ! -d $reporoot );
    my $pool=$reporoot."/pool";
    croak("pool '$pool' not created"), if( ! -d $pool );
}

sub test_addPackage {
    my $self=shift;

    # add a package
    my $name="testname";
    my $arch="testarch";
    my $version="testversion";
    my $release="release";
    my $platform="testplatform";
    my $package=Package::Mpp->new( { name=>"$name",
                                     version=>"$version",
                                     arch=>$arch,
                                     platform=>$platform  } );
    {
        my $rep=$self->_init();
        $rep->add($release, $package);
        my $pooldir=$rep->_poolDir($platform,$arch,$name,$version);
        die("expecting dir to exist:  ".$pooldir), if ( ! -d $pooldir );
    }
    {
        # check information has been stored
        my $rep=$self->_init();
        my @packs=$rep->packages($release,$platform);
        my @pinfo=();
        my @expect=("$name$version");
        for(@packs){
           push @pinfo, $_->{name}.$_->{version};
        }
        die("expecting @expect, got '@pinfo'"), if ( "@expect" ne "@pinfo" );
    }
    {
        # remove the package
        my $rep=$self->_init();
        $rep->remove($release,$package);
        my @packs=$rep->packages($release,$platform);
        my $pinfo="";
        for(@packs){
            $pinfo.=$_->{name}.$_->{version};
        }
        die("expecting nothing, got '$pinfo'"), if ( "$pinfo" ne "" );
    }
}

sub test_removePackage {
    my $self=shift;

    my $release1="release1";
    my $release2="release2";
    my $name="testname";
    my $arch="testarch";
    my $platform="testplatform";
    my $version="testversion";
    my $rep=$self->_init();

    # add the same package to multiple releases
    my $package=Package::Mpp->new( { name=>"$name",
                                     version=>"$version",
                                     platform=>"$platform",
                                     arch=>$arch }  );
    $rep->add($release1, $package);
    $rep->add($release2, $package);

    # remove from a single release - expect package
    # to remain
    $rep->remove($release1, $package);
    my $pooldir=$rep->_poolDir($platform,$arch,$name,$version);
    die("expecting dir to exist:  ".$pooldir), if ( ! -d $pooldir );

    # check package has been removed
    $rep->remove($release2, $package);
    die("expecting dir to be removed:  ".$pooldir), if ( -d $pooldir );
}

sub _init {
    my $self=shift;
    my $reporoot=$self->{tmpdir}."/testrepo";

    my $config->{root}=$reporoot;
    #$config->{verbose}=1;
    my $rep=Publishers::Mpp->new($config);
    return $rep;
}
