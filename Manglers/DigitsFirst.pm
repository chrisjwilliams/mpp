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
    $string=~s/^(\D+)\.(.*)/0.$2\.$1/; # replace any non digit before a . with 0
    $string=~s/^(\D+)(.+\..*)/$2\.$1/; # replace any non digit before a . at the end
    $string=~s/^(\D+)(.*)/0.$2\.$1/; # if starts with anything else,.and no .
                                     # then move word to end of the string, with a 0 prefix
    return $string;
}
