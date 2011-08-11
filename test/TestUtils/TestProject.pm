# ----------------------------------
# class TestUtils::TestProject
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package TestUtils::TestProject;
use Project;
use ProjectInfo;
use strict;
our @ISA=qw /Project/;
1;

sub new {
    my $class=shift;
    my $api=shift;
    my $config=shift;
    if( ! defined $config ) {
        $config=new INIConfig;
        $config->setVar("project","license","GPL");
    }
    my $info=ProjectInfo->new($config, $api->{tmpDir}, "testProject","testVersion");
    my $self=$class->SUPER::new($config, $api, $info);
    bless $self, $class;
    return $self;
}

