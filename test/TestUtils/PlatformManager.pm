# ----------------------------------
# class TestUtils::PlatformManager
# Description:
#    MppAPI that uses test configurations
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package TestUtils::PlatformManager;
use strict;
use PlatformManager;
our @ISA=qw /PlatformManager/;
1;

sub new {
    my $class=shift;
    my $tmpDir=shift;
    my $self=$class->SUPER::new(@_);
    $self->{tmpDir}=$tmpDir;
    return $self;
}

sub getPlatform {
    my $self=shift;
    my $platform=shift;
    my $p=$self->SUPER::getPlatform( $platform , $self->{api}->getDefaultContext());
    if( $platform eq "localhost" )
    {
        $p->setLoginUser( getlogin() );
        $p->setWorkDir( $self->{tmpDir}."/$platform");
        mkdir $self->{tmpDir}."/$platform";
        my $arch=`uname -m`;
        chomp $arch;
        $p->setArch($arch);
    }
    return $p;
}
