# ----------------------------------
# class Redirection
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Redirection;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{url}=shift;
    bless $self, $class;
    return $self;
}

sub url {
    my $self=shift;
    return $self->{url};
}
