# ----------------------------------
# class SysProcedure::ProcedureItem
# Description:
#
#-----------------------------------
# Methods:
# new(Platform) :
#-----------------------------------

package SysProcedure::ProcedureItem;
use Carp;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{platform}=shift;
    if( defined $self->{platform} ) {
        croak("expecting a Platform object"), if( ! $self->{platform}->isa("Platform") );
    }
    return $self;
}

sub platform {
    my $self=shift;
    return $self->{platform};
}
