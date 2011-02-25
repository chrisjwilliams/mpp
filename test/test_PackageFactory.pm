# ----------------------------------
# class test_PackageFactory
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_PackageFactory;
use PackageFactory;
use INIConfig;
use TestUtils::MppApi;
use strict;
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
    return qw( test_multiversion );
}

sub test_multiversion {
    my $self=shift;
    my $pf=$self->_init();

    # Use Case:
    # request for a package by name and without a version
    # where multiple versions of the package exist
    #
    # Expectation:
    # return the highest version available

    my $pname="multiversion";
    my $pkg=$pf->getPackage($self->{localhost}, $pname);
    die("expecting a package - got undef"), if ( ! defined $pkg );
    my $name=$pkg->name();
    die("expecting package $pname got $name"), if ( $pname ne $name );
    # "multiversion" tests for package with the same name
    # "multiversion-latest" tests for package with a different name
    # "multiversion-data" refers to packagen name from a a different 
    my $ename=join(",",sort("multiversion","multiversion-latest", "multiversion-datapkg")); 
    $name=PackageInfo::standardNames("runtime",$pkg);
    die("expecting package '$ename' got '$name'"), if ( $ename ne $name );
}

sub _init {
    my $self=shift;
    my $pf=$self->{api}->packageFactory();
    #$pf->{verbose}=1;
    return $pf;
}
