# ----------------------------------
# class Manglers::ReplaceNonAlphaNumeric
# Description:
#  Removes or replaces non-alphanumeric characters
#  and replae any underscores with a hyphen
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Manglers::ReplaceNonAlphaNumeric;
use strict;
use Manglers::Base;
our @ISA=qw /Manglers::Base/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub _mangleString {
    my $self=shift;
    my $string=shift;
    $string=~s/_/-/g; # TODO actually search for other no-alpha chars too
    return $string;
}
