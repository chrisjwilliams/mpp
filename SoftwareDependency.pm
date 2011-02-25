# ----------------------------------
# class SoftwareDependency
# Description:
#   High level software dependency information
#-----------------------------------
# Methods:
# new(name, INIConfig) :
# setVersion(String) : set a version string
# platformPackage(Platform) : returns the apropriate packageInfo 
#                     for a specific deployment of the software
#-----------------------------------

package SoftwareDependency;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{packageFactory}=shift;
    $self->{name}=shift;
    $self->{config}=shift;
    bless $self, $class;
    return $self;
}

sub name {
    my $self=shift;
    return $self->{name};
}

sub setVersion {
    my $self=shift;
    $self->{version}=shift;
}

sub id {
    my $self=shift;
    my $id=$self->{name};
    if( defined $self->{version} )
    {
        $id.="::".$self->{version};
    }
    return $id;
}

sub version {
    my $self=shift;
    return $self->{version};
}

sub hasVersionRestriction {
    my $self=shift;
    if( defined $self->{version} && $self->{version} ne "" ) { return 1; }
    return 0;
}

sub platformPackage {
    my $self=shift;
    my $platform = shift || return;
    my $pkg=$platform->platformManager()->packageFactory()->getPackage($platform, $self->{name}, $self->version());
    # merge in default configuration
    $pkg->merge($self->{config});
    return $pkg;
}
