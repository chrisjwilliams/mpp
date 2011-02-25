# ----------------------------------
# class test_PackageDependencies
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_PackageDependencies;
use PackageDependencies;
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
    return qw( test_dependencies test_platformDependencies_build 
               test_platformDependencies_runtime
               test_addRemoveDependencies
                );
}

sub test_addRemoveDependencies {
    my $self=shift;
    my $sw = $self->{api}->getSoftwareManager();
    my $name = "testpackage";
    my $version = "testversion";
    
    # use case:
    # add a dependency with no version 
    # use both an undefined and an explicitly defined type
    {
      foreach my $type ( undef, "" , "build" ) {
        my $config = INIConfig->new();
        my $pkg = $sw->getPackage($name);
        die("expecting undefined version"), if( defined $pkg->version() );
        my $dep=new PackageDependencies($config);
        $dep->addDependencies( $type,$pkg );
        my @builddeps=$dep->dependencies($type);
        my @buildexpect=($name);
        die "wrong number of dependencies returned (got ".($#builddeps+1)
            .", expecting ".($#buildexpect+1).")", if ( $#builddeps != $#buildexpect );
        foreach my $dep ( @builddeps ) {
            die ("unexpected package ".($dep->{name})), 
                 if  ( ! grep ( /$dep->{name}/, @buildexpect ));
        }

        # -- check the underlying INConfig is updated (WHITEBOX test)
        my $key=$dep->_getSection($type);
        @builddeps = $config->list($key);
        die "wrong number of dependencies returned (got ".($#builddeps+1).
            ", expecting ".($#buildexpect+1).") (@builddeps)", if ( $#builddeps != $#buildexpect );

        # -- can we remove it
        $dep->removeDependencies("build",$pkg);
        @buildexpect=();
        @builddeps=$dep->dependencies("build");
        die "wrong number of dependencies returned (got ".($#builddeps+1)
            .", expecting ".($#buildexpect+1).") @builddeps", if ( $#builddeps != $#buildexpect );
      }
    }
    # use case:
    # add a dependency with version
    {
        my $config = INIConfig->new();
        my $pkg = $sw->getPackage($name, $version);
        die("expecting defined version"), if( ! defined $pkg->version() );
        my $dep=new PackageDependencies($config);
        $dep->addDependencies( "build",$pkg );
        my @builddeps=$dep->dependencies("build");
        my @buildexpect=($name);
        die "wrong number of dependencies returned (got ".($#builddeps+1).
            ", expecting ".($#buildexpect+1).")", if ( $#builddeps != $#buildexpect );
        foreach my $dep ( @builddeps ) {
            die ("unexpected package ".($dep->{name})), if  ( ! grep ( /$dep->{name}/, @buildexpect ));
        }
    }

}

sub test_dependencies {
    my $self=shift;

    my $config=INIConfig->new($self->{testConfigDir}."/dependencies.ini");
    my $dep=new PackageDependencies($config);
    my @deps=$dep->dependencies();
    my @expect=sort(qw(package_any_version packaged_versioned package_ver ));
    die "wrong number of dependencies returned (got ".($#deps+1).", expecting ".($#expect+1).")", if ( $#deps != $#expect );
    foreach my $dep ( @deps ) {
        die ("unexpected package ".($dep->{name})), if  ( ! grep ( /$dep->{name}/, @expect ));
    }
    my @buildexpect=qw(allplatform_build);
    my @builddeps=$dep->dependencies("build");
    die "wrong number of dependencies returned (got ".($#builddeps+1).", expecting ".($#buildexpect+1).")", if ( $#builddeps != $#buildexpect );
    foreach my $dep ( @builddeps ) {
        die ("unexpected package ".($dep->{name})), if  ( ! grep ( /$dep->{name}/, @buildexpect ));
    }
}

sub test_platformDependencies_build {
    my $self=shift;

    my $config=INIConfig->new($self->{testConfigDir}."/dependencies.ini");
    my $dep=new PackageDependencies($config);
    # must allow multiple versions of the same package
    my @builddeps=$dep->platformDependencies($self->{localhost},"build");
    my @buildexpect=$self->_createPInfo( { name=>"package_any_version" }, { name=>"packaged_versioned", version=>"2.0" } ,
                                         { name=>"package_ver", version=>"6.0" }, { name=>"another_package" },
                                         { name=>"build_package"}, { name=>"allplatform_build" }, 
                                         { name=>"test_b_build" }, { name=>"test_c_common" } );
    $self->_compareDeps( [@builddeps] , [@buildexpect] );
}

sub test_platformDependencies_runtime {
    my $self=shift;
    my $config=INIConfig->new($self->{testConfigDir}."/dependencies.ini");
    my $dep=new PackageDependencies($config);
    my @runtimeexpect=$self->_createPInfo( { name=>"package_any_version" }, { name=>"packaged_versioned", version=>"2.0" },
                                          { name=>"package_ver", version=>"6.0" }, { name=>"another_package" },
                                          { name=>"test_c_common" } );
    my @runtimedeps=$dep->platformDependencies($self->{localhost},"runtime");
    $self->_compareDeps( [@runtimedeps] , [@runtimeexpect] );
}

sub _createPInfo {
    my $self=shift;
    my @pkgs;
    for(@_) {
        push @pkgs, PackageInfo->new( $_->{name}, $_->{version} );
    }
    return @pkgs;
}

sub _compareDeps {
    my $self=shift;
    my $mode=shift;
    my $dep1=shift;
    my $dep2=shift;
    my @deps1=sort(PackageInfo::standardNames($mode, @{$dep1}));
    my @deps2=sort(PackageInfo::standardNames($mode, @{$dep2}));
    die("expecting: \"@deps2\"\n\tgot      : \"@deps1\" "), if( "@deps1" ne "@deps2" );
}

sub _printDeps {
    my $self=shift;
    my @deps=@_;

    return PackageInfo::standardNames(@_);
}
