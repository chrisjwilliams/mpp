# ----------------------------------
# class TestUtils::TestPlatform
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package TestUtils::TestPlatform;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{work}=shift;
    bless $self, $class;
    return $self;
}

sub name {
    return "TestPlatform";
}

sub packageManagerType {
    return "test";
}

sub arch {
   return "TestArch";
}

sub platform {
   return "TestPlatform";
}

sub packageType {
   return "test";
}

sub workDir {
   my $self=shift;
   return $self->{work};
}

sub locations {
   my $self=shift;
   return {};
}
