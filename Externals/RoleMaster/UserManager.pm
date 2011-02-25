# ----------------------------------
# class RoleMaster::UserManager
# Description:
#   Front end API for all accessing RoleMaster
#   functionality
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package RoleMaster::UserManager;
use RoleMaster::User;
use RoleMaster::Group;
use RoleMaster::Role;
use RoleMaster::FileDBDriver;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;

    # -- setup database
    $self->{driver}=shift;
    $self->{driver}->setManager($self);

    return $self;
}

sub currentUserApache {
    my $self=shift;
    my $username=$ENV{REMOTE_USER};
    my $auth=$ENV{AUTH_TYPE};
    return $self->getUser($username,$auth);
}

sub newUser {
    my $self=shift;
    my $name=shift || return;
    my $user = new RoleMaster::User($self,$name);
    $self->{driver}->createUser($user);
    $self->{users}{$user->id()}=$user;
    return $user;
}

sub getUser {
    my $self=shift;
    my $username=shift;
    my $authority=shift;
    my $user = new RoleMaster::User($self->{driver}->getUserId($authority,$username));
    $self->{driver}->restoreUser($user);
    return $user;
}

# --- Role
sub getRoleId {
    my $self=shift;
    my $name=shift;
    my $group=shift;

    $self->{driver}->getRoleId($name,$group);
}

sub getRole {
    my $self=shift;
    my $rid=shift || return;

    if( ! defined $self->{roles}{$rid} )
    {
        my $role=RoleMaster::Role->new("",$rid);
        $self->{driver}->restoreRole($role);
        $self->{roles}{$rid}=$role;
    }
    return $self->{roles}{$rid};
}

sub saveRole {
    my $self=shift;
    my $role=shift;
    if( defined $role->id() ) {
        $self->{driver}->saveRole($role);
    }
    else {
        $self->{driver}->createRole($role);
    }
}

# -- group 

sub getGroup {
    my $self=shift;
    my $gpid=shift || return;

    if( ! defined $self->{groups}{$gpid} )
    {
        my $group = new RoleMaster::Group($self, $gpid);
        $self->{driver}->restoreGroup($group);
        $self->{groups}{$gpid}=$group;
    }
    return $self->{groups}{$gpid};
}

sub saveGroup {
    my $self=shift;
    my $group=shift;
    $self->{driver}->saveGroup($group);
}

sub newGroup {
    my $self=shift;
    my $gpid=shift || return;
    my $group = new RoleMaster::Group($self,$gpid);
    $self->{driver}->createGroup($group);
    $self->{groups}{$gpid}=$group;
    return $group;
}
