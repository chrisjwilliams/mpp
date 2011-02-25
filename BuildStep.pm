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
    bless $self, $class;
    return $self;
}

sub executeStep {
    my $self=shift;
    my $platform=shift;
    my $log =shift;

    croak "no platform defined", if ( ! defined $platform );
    return $self->{project}->buildPlatform($platform, $log);
}
