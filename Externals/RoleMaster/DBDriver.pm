# ----------------------------------
# class RoleMaster::DBDriver
# Description:
#    SQL Database driver for User data
#-----------------------------------
# Methods:
# new() : Pass down the appropriate databse handle
#-----------------------------------


package RoleMaster::DBDriver;
use DBI;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{dbh}=shift; 
    bless $self, $class;
    return $self;
}

sub setManager {
    my $self=shift;
    $self->{api}=shift;
}

sub setup {
    my $self=shift;
    my @sqls;
    push @sqls,"CREATE TABLE \"authorities\" (id int, name char(50))";
    push @sqls,"CREATE TABLE \"authusers\" (authority int, username char(50), userId int)";
    push @sqls,"CREATE TABLE \"users\" (id int, username char(50))";
    push @sqls,"CREATE TABLE \"groups\" (id int primary key, name char(50) )";
    push @sqls,"CREATE TABLE \"roles\" (id int primary key, name char(50) )";
    push @sqls,"CREATE TABLE \"roleAssociations\" (roleId int, subservientId int )";
    push @sqls,"CREATE TABLE \"groupRoles\" (groupId int, userId INT, roleId int )";

    foreach my $sql ( @sqls ) {
        my $sth = $self->{dbh}->prepare($sql);
        $sth->execute();
    }
}

#
# ----------- User Object ---------------
#

sub getUserId {
    my $self=shift;
    my $auth=shift || return;
    my $username=shift || return;
    my $sql="SELECT UserId FROM authusers WHERE authority=\"$auth\" ".
            "AND username EQUALS $username";
    my $sth = $self->{dbh}->prepare($sql);
    my $id=$sth->execute();
    return $id;
}

sub createUser {
    my $self=shift;
    my $user=shift;

    my $sql="INSERT INTO users (username) VALUES (?)";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($user->id());
}

sub restoreUser {
    my $self=shift;
    my $user=shift;
    my $id=$user->id() || return;

    my $sql="SELECT username FROM users WHERE id EQUALS $id";
    my $sth = $self->{dbh}->prepare($sql);
    my @vals=$sth->execute();
    $user->setName($vals[0]);
}

sub deleteUser {
    my $self=shift;
    my $user=shift;
    my $id=$user->id();
    my $sql="DELETE FROM users WHERE id=\"$id\"";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();
}

#
# ----------- Group Object ---------------
#
sub createGroup {
    my $self=shift;
    my $group=shift;
    my $name=$group->id() || return;

    # -- create the group table entry
    my $sql="INSERT INTO groups (name) VALUES (\"$name\")";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    $self->saveGroupRoles($group);
}

sub saveGroupRoles {
    my $self=shift;
    my $group=shift;

    # -- create role associations
    my $sql="INSERT INTO groupRoles (groupId, roleId) VALUES (?, ?)";
    my $sth = $self->{dbh}->prepare($sql);
    my $usql="INSERT INTO groupRoles (groupId, roleId, userId) VALUES (?, ?, ?)";
    my $sth2=$self->{dbh}->prepare($usql);

    foreach my $role ( $group->roles() ) {
        my $roleId = $role->id();
        # Insert the NULL user to mark an associated role
        $sth->execute($group->id(), $roleId);
        # -- insert member into role for this group
        foreach my $mem ( $group->listMembers($role) )
        {
            $sth2->execute($group->id(), $roleId, $mem->id());
        }
    }
}

sub restoreGroup {
    my $self=shift;
    my $group=shift;
    my $id=$group->id();
    my $sql="SELECT name FROM groups WHERE id=\"$id\"";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();
    my ($name)=$sth->fetchrow_array();
    $group->setName($name);

    # -- role associations
    $sql="SELECT roleId, userId FROM groupRoles WHERE groupId=\"$id\"";
    $sth = $self->{dbh}->prepare($sql);
    $sth->execute();
    while ( my @row = $sth->fetchrow_array() )
    {
        if( defined $row[1] && $row[1] ne "0" ) {
            $group->addMember( $self->{api}->getUser($row[1]), 
                            $self->{api}->getRole($row[0]) );
        }
        else {
            $group->addRoles( $self->{api}->getRole($row[0]) );
        }
    }
}

sub saveGroup {
    my $self=shift;
    my $group=shift;

    my $id=$group->id();
    my $name=$group->name();

    # -- update the groups name
    my $sql;
    my $sth;
    if ( defined $name ) {
        $sql="UPDATE groups SET name=\"$name\" WHERE id=\"$id\"";
        $sth = $self->{dbh}->prepare($sql);
        $sth->execute();
    }

    # -- remove all references to the group in tables
    $sql="DELETE FROM groupRoles WHERE groupId=\"$id\"";
    $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

    # -- rewrite the new roles
    $self->saveGroupRoles($group);
    
}

sub deleteGroup {
    my $self=shift;
    my $group=shift;

    my $id=$group->id();

    # -- remove the group table entry
    my $sql="DELETE FROM groups WHERE id=\"$id\";";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

}

#
# -----------  Role Object ---------------
#

sub getRoleId {
    my $self=shift;
    my $name=shift;
    my $group=shift;
    my $gid=$group->id();
    my $sql="SELECT roleId FROM roles,groupRoles WHERE groupRoles.groupId=\"$gid\"".
            "AND roles.name=\"$name\"";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();
    my $id;
    return $id;
}

sub createRole {
    my $self=shift;
    my $role=shift;

    my $sql="INSERT INTO roles (name) values (?)";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute($role->name());
    $self->saveRoleData($role);
}

sub saveRole {
    my $self=shift;
    my $role=shift;
    my $id=$role->id() || return;
    my $name=$role->name();
    my $sql;
    my $sth;

    # -- update the name field
    if( defined $name ) {
       $sql="UPDATE roles SET name=\"$name\" WHERE id=\"$id\"";
       $sth = $self->{dbh}->prepare($sql);
       $sth->execute();
    }

    $self->saveRoleData($role);
}

sub saveRoleData {
    my $self=shift;
    my $role=shift || return;
    my $id=$role->id() || return;
    my $sql="INSERT INTO roleAssociations (roleId, subservientId) VALUES (?, ?)";
    my $sth = $self->{dbh}->prepare($sql);
    foreach my $r ( $role->subserviantRoles() ) {
        $sth->execute();
    }
}

sub restoreRole {
    my $self=shift;
    my $role=shift || return;
    my $id=$role->id() || return;

    # -- restore the name
    my $sql="SELECT name FROM roles WHERE id=\"$id\"";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();
    my ($name)=$sth->fetchrow_array();
    $role->setName($name);

    # -- restore subserviant roles
}

sub deleteRole {
    my $self=shift;
    my $role=shift || return;
    my $id=$role->id() || return;

    # -- remove the group table entry
    my $sql="DELETE FROM roles WHERE id=\"$id\";";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute();

}

#
# -----------  Authority Object ---------------
#

sub createAuthority {
    my $self=shift;
    my $auth=shift;
}

sub restoreAuthority {
    my $self=shift;
    my $auth=shift;
}

sub deleteAuthority {
    my $self=shift;
    my $auth=shift;
}
