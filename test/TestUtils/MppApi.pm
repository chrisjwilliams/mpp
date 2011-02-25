# ----------------------------------
# class TestUtils::MppApi
# Description:
# MppApi interface for use with Testing Modules
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package TestUtils::MppApi;
use strict;
use MppAPI;
use INIConfig;
our @ISA=qw /MppAPI/;
use FindBin;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{testConfigDir}=shift;
    $self->{tmpDir}=shift;
    $self->{src}=$FindBin::Bin."/..";
    $self->{prjloc}=$self->{testConfigDir}."/Projects";
    $self->{platformbase}=$self->{testConfigDir}."/Platforms";
    $self->{softwareloc}=$self->{testConfigDir}."/Software";
    my $testconfig=$self->{testConfigDir}."/config.ini";
    if( -f $testconfig ) {
        $self->{config}=INIConfig->new($self->{testConfigDir}."/config.ini");
    }
    else {
        $self->{config}=INIConfig->new();
    }
    $self->{config}->setVar("publisher::mpp_test", "root", $self->{tmpDir}."/simplePub" );
    $self->{config}->setVar("publisher::mpp_test", "type", "simple" );
    if( ! defined $self->{config}->var("mpp","softwareDir") ) {
        $self->{config}->setVar("mpp","softwareDir",$self->{softwareloc});
    }
   
    bless $self, $class;
    return $self;
}

sub getPlatformManager {
    require TestUtils::PlatformManager;
    my $self=shift;
    if ( ! defined $self->{platm} ) {
        $self->{platm}=TestUtils::PlatformManager->new($self->{tmpDir},$self->{config}, $self->{platformbase}, $self );
    }
    return $self->{platm};
}
