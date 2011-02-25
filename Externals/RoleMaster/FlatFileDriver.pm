# ----------------------------------
# class RoleMaster::FlatFileDriver
# Description:
#   Uses INI files to store configuration
#   information
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package RoleMaster::FlatFileDriver;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    return $self;
}

sub createUser {
    my $self=shift;
    my $user=shift;
}

sub getUserId {
   my $user=shift;
   my $auth=$user->authority();
   return $id;
}

sub restoreUserById {
   my $user=shift;
}

sub createGroup {
    my $self=shift;
}

