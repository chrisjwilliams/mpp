# ----------------------------------
# class BuildStep
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package BuildStep;
use Carp;
use ExecutionStep;
use Project;
use strict;
our @ISA=qw /ExecutionStep/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    my $name=shift;
    my $context=shift;
    my $dir=shift;
    $self->{project}=shift;
    $self->{api}=shift;
    bless $self, $class;
    return $self;
}

sub executeStep {
    my $self=shift;
    my $platform=shift;
    my $log =shift;

    croak "no platform defined", if ( ! defined $platform );
    # -- ensure we build any custom dependencies
    my $deps = $self->{project}->{project}->dependencies()->customBuildPackages($platform);
    foreach my $dep ( keys %{$deps} ) {
        my $depProject=$self->{api}->getProjectManager()->getProject($dep, $deps->{$dep});
        if( $depProject->statusPlatform("build", $platform) ne "built" ) {
            $depProject->buildPlatform($platform, $log);
            $depProject->_publishPlatform($platform, "mpp_test" );
        }
    }
    # -- now build the actual project
    return $self->{project}->buildPlatform($platform, $log);
}
