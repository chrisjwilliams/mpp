# ----------------------------------
# class PlatformGroupPage
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package PlatformGroupPage;
use strict;
use Page;
our @ISA=qw /Page/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

