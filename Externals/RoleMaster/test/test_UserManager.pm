# ----------------------------------
# class test_UserManager
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_UserManager;
use RoleMaster::UserManager;
use RoleMaster::FileDBDriver;
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
    return qw( test_drivers );
}

sub test_drivers {
    my $self=shift;
    my @drivers;

    # --- setup the FileDB driver
print "creating db in ",$self->{tmpdir},"...\n";
    my $filedb=RoleMaster::FileDBDriver->new( $self->{tmpdir} );
    push @drivers, $filedb;
    foreach my $driver ( @drivers ) {
        eval {
            $self->test_group($driver);
        };
        if ($@) {
            die( "Driver:\"".(ref($driver))."\" $@" );
        }
    }
}

sub test_group {
    my $self=shift;
    my $driver=shift;

    my $testGpId="testGroup";
    my $gp;
    my $user;
    { 
      # Use Case:
      # create a new group with no internal data
      # Expect:
      # group to become available
      {
          # context to create a group
          my $um = $self->newUM($driver);
          $gp = $um->newGroup($testGpId);
      }
      # attempt to restore the group
      my $um = $self->newUM($driver);
      my $gpret = $um->getGroup($testGpId);
      die("group not created as required"), if ( $gpret->equals($gp) );
    }
    {
      # Use Case:
      # save a group with internal data
      # Expect:
      # group to be restorable
      {
          my $role1 = RoleMaster::Role->new("testRole1",1); # does not exist in db
          my $role2 = RoleMaster::Role->new("testRole2",2); # does not exist in db
          {
              my $um = $self->newUM($driver);
              $user = $um->newUser("testUser"); # guaranteed to exist
              $gp->addRoles($role1);
              $gp->addMember( $user, $role2);
              $gp->save();
          }
          my $um = $self->newUM($driver);
          my $rgp = $um->getGroup($testGpId);
          die("group not restored"), if ( ! defined $rgp );
          die("group not created as required"), if ( ! $gp->equals($rgp) );
      }
    }
}

sub newUM {
     my $self=shift;
     my $driver=shift;
     return new RoleMaster::UserManager($driver);
}
