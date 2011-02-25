# ----------------------------------
# class SoftwareManagerCollection
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package SoftwareManagerCollection;
use strict;
use MppClass;
our @ISA=qw /MppClass/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub addManager {
    my $self=shift;
    my $manager=shift;
    push @{$self->{managers}}, $manager;
}

sub getPackageById {
    my $self=shift;
    my $id = shift || return;
    my ($name, $version) = split("::",$id);
    return $self->getPackage( $name, $version);
}

sub listPackages {
    my $self=shift;
    my @packs;
    foreach my $manager ( @{$self->{managers}} )
    {
        push @packs, $manager->listPackages(@_);
    }
    return @packs;
}

sub getPackage {
    my $self=shift;
    foreach my $manager ( @{$self->{managers}} )
    {
        return $manager->getPackage(@_); # FIXME - this will only ever take the first
    }
    return undef;
}
