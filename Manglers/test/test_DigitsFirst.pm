# ----------------------------------
# class test_DigitsFirst
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_DigitsFirst;
use Manglers::DigitsFirst;
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
    return qw( test_method );
}

sub test_method {
    my $self=shift;
    my $mangler=new Manglers::DigitsFirst;
    $self->_testString($mangler,"v1.0", "1.0v");
    $self->_testString($mangler,"svn1.0", "1.0svn");
    $self->_testString($mangler,"svn.1.0", "0.1.0.svn");
}

sub _testString {
    my $self=shift;
    my $mangler=shift;
    my $in=shift;
    my $exp=shift;
    my $out=$mangler->mangle($in);
    die("$in -> expecting $exp, got $out"), if($out ne $exp);

}

