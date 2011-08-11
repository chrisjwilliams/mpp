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
    bless $self, $class;
    return $self;
}

sub name {
    return "TestPlatform";
}
