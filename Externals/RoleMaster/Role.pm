# ----------------------------------
# class RoleMaster::Role
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package RoleMaster::Role;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{name}=shift;
    $self->{id}=shift;
    bless $self, $class;
    return $self;
}

sub setId {
    my $self=shift;
    $self->{id}=shift;
}

sub id {
    my $self=shift;
    return $self->{id};
}

sub setName {
    my $self=shift;
    $self->{name} = shift;
}

sub name {
    my $self=shift;
    return $self->{name};
}

#
# return true if the role is subserviant (or the same)
#
sub contains {
    my $self=shift;
    my $role = shift || return 0;
    return 1, if( $role->{name} eq $self->{name} );
    foreach my $r ( @{$self->{roles}} ) {
        return 1, if( $r->{name} eq $role->{name});
    }
    return 0;
}
#
# Mark other roles that are included in the permissions
# of this role
#
sub setSubserviantRoles {
    my $self=shift;
    push @{$self->{roles}}, @_;
}

sub subserviantRoles {
    my $self=shift;
    return @{$self->{roles}};
}

