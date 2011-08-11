# ----------------------------------
# class TestUtils::BuiltTestProject
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package TestUtils::BuiltTestProject;
use strict;
use TestUtils::TestProject;
our @ISA=qw /TestUtils::TestProject/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub statusPlatform {
    return "built";
}
