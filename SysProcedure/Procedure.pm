# ----------------------------------
# class SysProcedure::Procedure
# Description:
#    Describe a procedure of commands and 
#    file installation
#-----------------------------------
# Methods:
# new()  :
# execute([FileHandle log],root) : run the procedure based at the root specified
# add(ProcedureItem) : Add a procedure Item to the execution list
#-----------------------------------

package SysProcedure::Procedure;
use SysProcedure::ProcedureItem;
use Carp;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    return $self;
}

sub execute {
    my $self=shift;
    for( @{$self->{proc}})
    {
        $_->execute(@_);
    }
}

sub add {
   my $self=shift;
   for(@_) {
       $_->isa("SysProcedure::ProcedureItem") or croak("expecting a SysProcedure::ProcedureItem");
       push @{$self->{proc}}, $_;
   }
}
