# ----------------------------------
# class TestStep
# Description:
#   Run the testing step for a project
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package TestStep;
use Carp;
use strict;
use ExecutionStep;
our @ISA=qw /ExecutionStep/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    my $name=shift;
    my $context=shift;
    my $dir=shift;
    $self->{project}=shift;
    $self->{release}=shift;
    $self->{publication}=shift;
    bless $self, $class;
    return $self;
}

sub executeStep {
    my $self = shift;
    my $platform = shift;
    my $log =shift;

    # -- publish to the test repo
    my $rep=$self->{publication}->publish( "mpp_test", $self->{project}, $platform );
    $rep->summary($log,"publishPlatform") ;
    return $rep, if( $rep->failed() );

    # -- add the required release repository
    my @reps=$self->{publication}->setupRepositories( $log, $self->{release}, $platform );

    # -- add the mpp repository and publish package to this
    push @reps,$self->{publication}->setupRepositories( $log, "mpp_test", $platform );

    # -- instruct the platfrom to install the package
    $platform->updatePackageInfo($log);;
    $self->{project}->install( $platform, $log );
    
    # -- perform the test
    my $report=$self->{project}->_testPlatform($platform, $log );
    $report->summary($log,"test");

    # -- remove from the mpp repository
    $platform->installPackages($log, $self->{project}->packageName($platform));

    # -- remove the release repository
    $self->{publication}->removeRepositories( $log, $platform, $self->{release}, @reps );

    # -- clean up
    $self->{publication}->unpublish("mpp_test", $self->{project}, $platform);
    return $report;
}
