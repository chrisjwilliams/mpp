# ----------------------------------
# class Package::Package
# Description:
#   Container class 
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Package::Package;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{config}=shift;
    $self->{name}=$self->{config}{name} || "";
    $self->{version}=$self->{config}{version} || "";
    @{$self->{packagefiles}}=();
    return $self;
}

sub type {
    my $self=shift;
    return ($self->{config}{type} || ref($self));
}

sub name {
    my $self=shift;
    return $self->{name};
}

sub version {
    my $self=shift;
    return $self->{version};
}

sub arch {
    my $self=shift;
    return $self->{config}{arch};
}

sub platform {
    my $self=shift;
    return $self->{config}{platform};
}

sub setFiles {
    my $self=shift;
    push @{$self->{packagefiles}}, @_;
}

sub packageFiles {
    my $self=shift;
    return @{$self->{packagefiles}};
}
