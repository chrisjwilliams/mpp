# ----------------------------------
# class test_Group
# Description:
#  Test the Group class
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_Group;
use RoleMaster::Group;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    return $self;
}

sub tests {
    return qw( test_roles test_members test_equals);
}

sub test_roles {
    my $self=shift;

    { 
        # use case:
        # No roles defined
        # expect empty array form call to roles()
        
    }
    
}

sub test_members {
    my $self=shift;
    my $userid="testid";
    my $testrole="testRole";
    { 
        # use case:
        # Add a user that does not exist
        # expect:
        # return quietly
        my $gp = $self->_newGroup();
        $gp->addMember(undef,undef);
        die("member added wrongly"), if( scalar $gp->listMembers() > 0 );

        # use case:
        # Add a valid user without a group
        # expect:
        # return quietly
        my $user = RoleMaster::User->new($userid);
        $gp->addMember(new RoleMaster::User(),undef);
        die("member added wrongly"), if( scalar $gp->listMembers(undef) > 0 );
    }
    { 
        # use case:
        # Add a valid user to a specified role
        # expect:
        # user to become part of the group
        # and to have permissions for that role (and below)
        my $gp = $self->_newGroup();
        my $user = RoleMaster::User->new($userid);
        my $role = new RoleMaster::Role($testrole, 1);
        my $role2 = new RoleMaster::Role("2",2);
        my $role3 = new RoleMaster::Role("3",3);
        $role->setSubserviantRoles($role3);
        $gp->addMember($user, $role);
        die( "role not recorded" ), if ( ! $gp->hasRole($role) );

        my @members=$gp->listMembers($role);
        die("user not added as expected (got $#members)"), if( $#members != 0 );
        @members=$gp->listMembers($role2);
        die("user not added as expected "), if( $#members != -1 );
        @members=$gp->listMembers($role3);
        die("user not included in subsiduary role "), if( $#members != 0 );

        # use case:
        # remove user from the a different role 
        # expect:
        #  no changes
        $gp->removeMember( $user, $role2 );
        @members=$gp->listMembers($role);
        die("user not added as expected "), if( $#members != 0 );
        @members=$gp->listMembers($role2);
        die("user not added as expected ("), if( $#members != -1 );

        # use case:
        # remove user from the specified role
        # expect:
        # user to dissapear from list
        $gp->removeMember( $user, $role );
        @members=$gp->listMembers($role);
        die("user not added as expected"), if( $#members != -1 );
        @members=$gp->listMembers($role2);
        die("user not added as expected"), if( $#members != -1 );
    }
    {
        # use case:
        # Add a valid user to a specified role
        # who already exists with a higher role
        # expect:
        # no changes to be made
        my $gp = $self->_newGroup();
        my $role = new RoleMaster::Role($testrole,1);
        my $role2 = new RoleMaster::Role("2",2);
        $role->setSubserviantRoles($role2);
        my $user = RoleMaster::User->new($userid);
        $gp->addMember($user,$role);
        die( "role not recorded" ), if ( ! $gp->hasRole($role) );

        my @members=$gp->listMembers($role);
        die("user not added as expected (got $#members)"), if( $#members != 0 );
        @members=$gp->listMembers($role2);
        die("user not added as expected "), if( $#members != 0 );

        $gp->addMember($user,$role2);
        die( "role not recorded" ), if ( ! $gp->hasRole($role2) );
        @members=$gp->listMembers($role);
        die("user not added as expected (got $#members)"), if( $#members != 0 );
        @members=$gp->listMembers($role2);
        die("user not added as expected "), if( $#members != 0 );
    }
    {
        # use case:
        # Add a valid user to a specified role
        # who already exists in a lower role
        # expect:
        # role of user to be upgraded
        my $gp = $self->_newGroup();
        my $role = new RoleMaster::Role($testrole,1);
        my $role2 = new RoleMaster::Role("2",2);
        $gp->addRoles($role,$role2);
        $role->setSubserviantRoles($role2);
        my $user = RoleMaster::User->new($userid);
        $gp->addMember($user,$role2);

        my @members=$gp->listMembers($role);
        die("user not added as expected (got $#members)"), if( $#members != -1 );
        @members=$gp->listMembers($role2);
        die("user not added as expected "), if( $#members != 0 );

        $gp->addMember($user,$role);
        @members=$gp->listMembers($role2);
        die("user not added as expected "), if( $#members != 0 );
        @members=$gp->listMembers($role);
        die("user not added as expected (got $#members)"), if( $#members != 0 );

        # Use case:
        # remove the user from the higher role
        # expect:
        # user to remain valid for lower role
        $gp->removeMember($user,$role);
        @members=$gp->listMembers($role2);
        die("user not added as expected "), if( $#members != 0 );
        @members=$gp->listMembers($role);
        die("user not added as expected (got $#members)"), if( $#members != -1 );

    }
}

sub test_equals {
    my $self=shift;
    my $gp1 = $self->_newGroup();
    my $gp2 = $self->_newGroup();

    die("empty group equality failed"), if( ! $gp1->equals($gp2) );
    # -- only name set
    my $name="testName";
    $gp1->setName($name);
    die("empty group equality failed"), if( $gp1->equals($gp2) );
    $gp2->setName($name);
    die("empty group equality failed"), if( ! $gp1->equals($gp2) );

    # -- roles set
    my $role1=RoleMaster::Role->new("1",1);
    my $role2=RoleMaster::Role->new("2",2);
    $gp1->addRoles($role1,$role2);
    die("empty group equality failed"), if( $gp1->equals($gp2) );
    $gp2->addRoles($role1,$role2);
    die("empty group equality failed"), if( ! $gp1->equals($gp2) );

    # -- members set
    my $user = RoleMaster::User->new("userid");
    $gp1->addMember($user,$role1);
    die("empty group equality failed"), if( $gp1->equals($gp2) );
    $gp2->addMember($user,$role1);
    die("empty group equality failed"), if( ! $gp1->equals($gp2) );

}

sub _newGroup {
    my $self=shift;
    my $gp=new RoleMaster::Group;
    return $gp;
}
