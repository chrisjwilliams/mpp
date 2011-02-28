# ----------------------------------
# class TestUtils::TestExecutionStep
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package TestUtils::TestExecutionStep;
use strict;
use ExecutionStep;
use Report;
our @ISA=qw /ExecutionStep/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    $self->{report} = new Report(); 
    $self->{report}->setReturnValue(0);
    $self->{toDie} = 0;
    bless $self, $class;
    return $self;
}

sub setToFail {
    my $self=shift;
    $self->{report} = shift;
    if( ! defined $self->{report} ) {
        $self->{report} = new Report(); 
        $self->{report}->setReturnValue(1);
        $self->{report}->addStderr("TestExecutionStep FAIL");
    }
}

sub setToThrow {
    my $self=shift;
    $self->{toDie} = shift || 1;
    $self->{report} = new Report(); 
    $self->{report}->addStderr("TestExecutionStep FAIL");
}

#
#  just return the Report
#
sub executeStep {
    my $self=shift;
    if ( $self->{toDie} == 1) {
        die( $self->{report}->stderr() ), 
    }
    return $self->{report};
}
