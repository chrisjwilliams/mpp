# ----------------------------------
# class test_ReleaseInfo
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_ReleaseInfo;
use MppPublisher::ReleaseInfo;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    return $self;
}

sub tests {
    return qw( test_packages );
}

sub test_packages {
    my $self=shift;
    my $ri=MppPublisher::ReleaseInfo->new($self->{tmpdir}."/ReleaseInfo.test");
    my $pkgs=$ri->packages();
    my @keys= keys %{$pkgs};
    die "expecting empty hash, got '@keys'", if ( "@keys" ne ""  );
    my $name="name";
    my $version="version";
    my $info="somewhere/info.info";
    $ri->addPackage($name,$version,$info);
    $pkgs=$ri->packages();
    die "expecting package $name", if ( !defined $pkgs->{$name} );
    my $pinfo=$ri->packageInfoFile($name,$version);
    die "expecting $info, got $pinfo", if ( $pinfo ne $info );
}
