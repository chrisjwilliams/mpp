# ----------------------------------
# class test_ExecutionStep
# Description:
#   Unit test for base class execution step
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_ExecutionStep;
use ExecutionStep;
use TestUtils::TestExecutionStep;
use TestUtils::MppApi;
use Context;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;

    $self->{api}=TestUtils::MppApi->new( $self->{testConfigDir}, $self->{tmpdir} );
    $self->{platformM}=$self->{api}->getPlatformManager();
    $self->{localhost}=$self->{platformM}->getPlatform("localhost");

    return $self;
}

sub tests {
    return qw( test_executeSinglePass test_executeSingleFail test_executeSingleThrow test_executeMulti);
}

sub test_executeSinglePass {
    my $self=shift;
    my $context = new Context( "ExecutionStepTestPass", $self->{tmpdir}."/ExecutionStepTestPass" );
    my $testplatform = $self->{localhost};
    {
        # Use Case:
        # execution returns OK
        # Expect:
        # status to be completed, no errors
        {
            my $s = TestUtils::TestExecutionStep->new( "test",$context );
            die("expected none status"), if( $s->platformStatus($testplatform) ne "none" );
            my $report = $s->executePlatform( $testplatform );
            die("report did not return expected value"), if( $report->returnValue() ne 0 );
            die("expected completed status"), if( $s->platformStatus($testplatform) ne "completed" );
        }

        # Reinstate the object
        # Status should show completed
        my $s= new ExecutionStep( "test",$context );
        die("expected completed status, got ".($s->platformStatus($testplatform))), if( $s->platformStatus($testplatform) ne "completed" );
    }
}

sub test_executeSingleFail {
    my $self=shift;
    my $context = new Context( "ExecutionStepTestFail", $self->{tmpdir}."/ExecutionStepTestFail");
    my $testplatform = $self->{localhost};
    {
        # Use Case:
        # execution fails normally
        # Expect:
        # status to be failed, errors
        {
            my $s = TestUtils::TestExecutionStep->new( "test",$context );
            $s->setToFail();
            die("expected none status"), if( $s->platformStatus($testplatform) ne "none" );
            my $report = $s->executePlatform( $testplatform );
            die("report did not return expected value"), if( $report->returnValue() == 0 );
            die("expected failed status"), if( $s->platformStatus($testplatform) ne "failed" );
        }

        # Reinstate the object
        # Status should show failed
        my $s= new ExecutionStep( "test",$context );
        die("expected failed status"), if( $s->platformStatus($testplatform) ne "failed" );
    }
}

sub test_executeSingleThrow {
    my $self=shift;
    my $context = new Context( "ExecutionStepTestThrow", $self->{tmpdir}."/ExecutionStepTestThrow" );
    my $testplatform = $self->{localhost};
    {
        # Use Case:
        # execution fails fatally (dies)
        # Expect:
        # status to be failed, errors
        {
            my $s = TestUtils::TestExecutionStep->new( "test",$context );
            $s->setToThrow();
            my $report = $s->executePlatform( $testplatform );
            die("expected a report object"), if( ! defined $report );
            die("report did not return expected value"), if( $report->returnValue() == 0 );
            die("expected failed status"), if( $s->platformStatus($testplatform) ne "failed" );
        }

        # Reinstate the object
        # Status should show failed
        my $s= new ExecutionStep( "test",$context );
        die("expected completed status"), if( $s->platformStatus($testplatform) ne "failed" );
    }
}

sub test_executeMulti {
    my $self=shift;
    my $testplatform = $self->{localhost};
    my $testplatform2 = $self->{localhost};

     
    my $context = new Context( "ExecutionStepMultiFail", $self->{tmpdir}."/ExecutionStepMutiFail" );
    # Use Case:
    # execution fails on all platforms
    # Expect:
    # status to be failed, platform reports to be accurate
    {
        my $s = TestUtils::TestExecutionStep->new( "test",$context );
        $s->setToFail();
        my $report = $s->execute( $testplatform, $testplatform2 );
        my @failed=$report->failedReports();
        die("exepcted 2 failures - got ".($#failed+1)), if ( $#failed != 1)
    }
    # Use Case:
    # execution passes on all platforms
    # Expect:
    # status to be failed, platform reports to be accurate
    {
        my $s = TestUtils::TestExecutionStep->new( "test",$context );
        my $report = $s->execute( $testplatform, $testplatform2 );
        my @failed=$report->failedReports();
        die("exepcted no failures - got ".($#failed+1)), if ( $#failed != -1)
    }
}
