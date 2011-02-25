# ----------------------------------
# class RoleMaster::Group
# Description:
#   A group of users and their associated roles
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package RoleMaster::Group;
use RoleMaster::User;
use RoleMaster::Role;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};

    $self->{db}=shift; # -- the main UserManager API object
    $self->{id}=shift;

    # -- defualts
    @{$self->{roles}} = ();
    @{$self->{roleIds}} = (); # -- meta info for not yet substantiate role objects

    bless $self, $class;
    return $self;
}

sub id {
   my $self=shift;
   return $self->{id};
}

sub name {
   my $self=shift;
   return $self->{name};
}

sub setName {
   my $self=shift;
   $self->{name} = shift;
}

#
#  Returns a list of users that could potentially be assigned
#  roles in the group, and that do not already exist in the group
#
sub eligibleCandidates
{
    my $self=shift;
    my $role=shift;

    # -- get full user list
    my @users;#=$self->{api}->allUsers();
    # -- apply existance filter
    return @users;
}

sub addMember {
    my $self=shift;
    my $mem=shift || return;
    my $role=shift || return;
    if( ! $self->hasRole( $role ) ) {
        $self->addRoles( $role );
    }
    $self->{members}{$role->id()}{$mem->id()} = $mem;
}

sub removeMember {
    my $self=shift;
    my $mem=shift || return;
    my $role=shift;
    delete $self->{members}{$role->id()}{$mem->id()};
}

sub roles {
    my $self=shift;
    # -- instantiate any role objects now we actually need them
    foreach my $rid ( @{$self->{roleIds}} )
    {
       push @{$self->{roles}}, $self->{db}->getRole( $rid );
       shift @{$self->{roleIds}}; # -- take off non-instantiated marker
    }
    return @{$self->{roles}};
}

sub memberHasRole {
    my $self=shift;
    my $id=shift || return 0;
    my $role=shift || return 0;

    return defined $self->{members}{$role->id()}{$id};
}

sub listMembers {
    my $self=shift;
    my $role=shift || return 0;

    my @mem;
    # -- check all roles for compliance
    foreach my $r ( $self->roles() ) {
        if( $r->contains($role) ) {
            push @mem, values %{$self->{members}{$r->id()}};
        }
    }

    # remove list duplicates
    my %seen = ();
    my @unique = grep { ! $seen{ $_ }++ } @mem;
    return @unique;
}

sub addRoles {
    my $self=shift;
    push @{$self->{roles}}, @_;
}

sub hasRole {
    my $self=shift;
    my $role=shift || return 0;

    # -- test all non-instantiated roles
    foreach my $r ( @{$self->{roleIds}} ) {
        return 1, if( $role->id() eq $r );
    }
    # -- test all instantiated role objects
    foreach my $r ( @{$self->{roles}} ) {
        return 1, if( $role->id() eq $r->id() );
    }
    return 0;
}

sub equals {
    my $self=shift;
    my $gp=shift;

    return 0, if( defined $self->{id} != defined $gp->{id} );
    if( defined $self->{id} ) {
        return 0, if( $self->{id} ne $gp->{id} );
    }
    return 0, if( defined $self->{name} != defined $gp->{name} );
    if( defined $self->{name} ) {
        return 0, if( $self->{name} ne $gp->{name} );
    }
    # -- check roles
    my @roles=$self->roles();
    my @groles=$gp->roles();
   
    return 0, if( $#roles != $#groles );

    # -- check role details/members
    for(my $i = 0; $i <= $#roles; ++$i ) {
        my $role=$roles[$i];
        return 0, if( $role->id() != $groles[$i]->id() );
        return 0, if( defined $self->{members}{$role->id()} != defined $gp->{members}{$role->id()} );
        if( defined $self->{members}{$role} ) {
        print "members", join (":",keys %{$self->{members}{$role->id()}}), "\n";
            return 0, if( join (":",keys %{$self->{members}{$role->id()}}) 
                      ne join (":", keys %{$gp->{members}{$role->id()}}) );
        }
    }
    return 1;
}

sub save {
    my $self=shift;
    $self->{db}->saveGroup($self);
}
