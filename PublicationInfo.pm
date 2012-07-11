# ----------------------------------
# class PublicationInfo
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package PublicationInfo;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    return $self;
}

sub addInstaller {
    my $self=shift;
    my $project=shift;
    push @{$self->{installers}}, $project;
}

sub addPlatform {
    my $self=shift;
    my $platform=shift;
    my $project=shift;

    push @{$self->{platforms}{$platform->name()}}, $project;
}
