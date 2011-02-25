# ----------------------------------
# class test_Procedure
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_Procedure;
use SysProcedure::Procedure;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    return $self;
}

sub tests {
    return qw( test_add );
}

sub test_add {
    my $self=shift;
    my $process=SysProcedure::Procedure->new();

    # -- good item
    my $gooditem=new SysProcedure::ProcedureItem();
    $process->add($gooditem);

    # -- bad item
    my $baditem="burk";
    eval {
        $process->add($baditem);
    };
    if($@) {
        return 0;
    }
}
