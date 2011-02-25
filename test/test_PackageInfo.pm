# ----------------------------------
# class test_PackageInfo
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_PackageInfo;
use TestUtils::MppApi;
use PackageInfo;
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
    return qw( test_expand test_packageNames);
}

sub test_expand {
    my $self=shift;
    my $pname="testproject";
    my $pver="testversion";
    my $p=PackageInfo->new($pname,$pver);
    my $env=Environment->new( {
                                 var1=>"a",
                                 var2=>"f",
                                 var3=>"e"
                              }
                            );
    $p->merge($env);

    # basic name version checks
    my $name=$p->name();
    die("got $name for package name"), if( $name ne $pname);
    my $version=$p->version();
    die("got $version for package version"), if( $version ne $pver);

    # -- set up a string to expand 
    # expect otherversion to not be expanded
    # but version specific and unspecified versions to be.
    #
    my $string='${pack::'.$pname.'::var1}b${pack::'.$pname.'::'.$pver.'::var2}c${pack::'.$pname.'::otherversion::var2}d';
    my $stringexpect='abfc${pack::testproject::otherversion::var2}d';
    $string=$p->expandString($string);
    die("expecting\n\t$stringexpect\ngot\n\t$string"), if ( $string ne $stringexpect );
}

sub test_packageNames {
    my $self=shift;

    my $pname="testproject";
    my $pver="testversion";
    my $pname2="testproject2";
    my $pver2="testversion2";
    {
        # test Case 1 : recursive package dependency - top level
        my $p=PackageInfo->new($pname,$pver);
        $p->setPackageNames($pname);
        $p->addDependency(PackageInfo->new($pname2,$pver2), $p, PackageInfo->new($pname,$pver) );
        my @names = $p->packageNames("any");
        my @enames = ($pname);
        die("expecting ",(join( " ",@enames)),", got ",(join( " ", @names))), if ("@enames" ne "@names" );
    }
    {
        # test Case 2 : recursive package dependency - sub package
        my $p=PackageInfo->new($pname,$pver);
        $p->setPackageNamesType("runtime",$pname);
        $p->setPackageNames("woof");
        my $p2=PackageInfo->new($pname2,$pver2);
        $p2->setPackageNames($pname2);
        $p2->addDependency($p);
        my @names = sort($p2->packageNames("runtime"));
        my @enames = sort($pname2,$pname,"woof");
        die("expecting ",(join( " ",@enames)),", got ",(join( " ", @names))), if ("@enames" ne "@names" );
        @names = sort($p2->packageNames("build"));
        @enames = sort($pname2,"woof");
        die("expecting ",(join( " ",@enames)),", got ",(join( " ", @names))), if ("@enames" ne "@names" );
    }
}
