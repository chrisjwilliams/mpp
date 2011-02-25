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
    bless $self, $class;
    return $self;
}

sub executeStep {
    my $self = shift;
    my $platform = shift;
    my $log =shift;

    return $self->{project}->_testPlatform($platform, $log );
}
