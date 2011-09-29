# ----------------------------------
# class PackageVersion
# Description:
#    class to manipulate and test package version numbers
#-----------------------------------
# Methods:
# new(verison string) :
              # >     ;
# setVersion()        :
#-----------------------------------


package PackageVersion;
use overload ">" => \&greaterThan;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->setVersion(shift);
    bless $self, $class;
    return $self;
}

sub setVersion {
    my $self=shift;
    $self->{string}=shift;
    my @($self->{versions})=split("\.",$self->{string});
}

sub greaterThan {
    my $self=shift;
    my $version=shift;
    for(my $i=0; $i<$#version; ++$i ) {
        if( scalar $self->{versions} > $i ) { return 1; };
        if( ${$version->{versions}[$i]} > ${$self->{versions}[$i]} ) {
            return 0;
        }
    }
    return 1;
}
