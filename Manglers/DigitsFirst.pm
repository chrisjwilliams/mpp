# ----------------------------------
# class Manglers::DigitsFirst
# Description:
# Reconstruct a string so that it always starts with a digit
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Manglers::DigitsFirst;
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
    $string=~s/^(\D+)(.*)/0.$2$1/; # if starts with anything else,.
                                   # then move word to end of the string
                                   # and insert a 0. before it
    return $string;
}
