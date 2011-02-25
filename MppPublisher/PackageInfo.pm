# ----------------------------------
# class MppPublisher::PackageInfo
# Description:
#    Parse an Mpp package.info 
#-----------------------------------
# Methods:
# new(@files) :
# packages() : return list of packageInfo objects of avialable packages
#-----------------------------------

package MppPublisher::PackageInfo;
use PackageInfo;
use INIConfig;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{filename}=shift;
    if( -f $self->{filename} ) {
        $self->{config}->INIConfig($file);
    }
    else {
        $self->{config}=INIConfig->new();
    }
    bless $self, $class;
    return $
}

sub getPackageInfo {
    my $self=shift;
    my $pinfo=shift;
    my $name=$pinfo->name();
    my $version=$pinfo->version();
    my $vertag=$version;
    $vertag="unknown", if( ! defined $vertag );

    if( ! defined $self->{packages}{$name}{$vertag}{$platform} ) {
        my $tag="pack::$name";
        my @sections=( $tag."::".$vertag, $tag);
        $tag.="::$version", if ( defined $version && $version ne "");
        my $pkg=PackageInfo->new($name,$vertag);
    }
}


sub packages {
    my $self=shift;
    my $arch=shift;

}
