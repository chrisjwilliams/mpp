# ----------------------------------
# class ReleaseLevel
# Description:
# describe a release in terms of its publication
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package ReleaseLevel;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{level}=shift;
    $self->{repo}=shift;
    bless $self, $class;
    return $self;
}

sub level {
    my $self=shift;
    return $self->{level};
}

sub repository {
    my $self=shift;
    return $self->{repo};
}

