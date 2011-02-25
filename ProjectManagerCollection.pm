# ----------------------------------
# class ProjectManagerCollection
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package ProjectManagerCollection;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    return $self;
}

sub addManager {
    my $self=shift;
    my $manager=shift;
    push @{$self->{managers}}, $manager;
}

sub listProjects {
    my $self=shift;
    my @prjs;

    foreach my $manager ( @{$self->{managers}} )
    {
        push @prjs, $manager->listProjects(@_);
    }
    return @prjs;
}

sub getProject {
    my $self=shift;
    my $name=shift;
    my $version=shift;

    my $project;
    foreach my $manager ( @{$self->{managers}} )
    {
        if( defined ($project=$manager->getProject($name,$version)) ) { last; }
    }
    return $project;
}
