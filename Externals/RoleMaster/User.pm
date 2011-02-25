# ----------------------------------
# class RoleMaster::User
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package RoleMaster::User;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{id}=shift; # unigue identifier
    bless $self, $class;
    return $self;
}

sub id {
    my $self=shift;
    return $self->{id};
}
