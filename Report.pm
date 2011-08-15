# ----------------------------------
# class Report
# Description:
#  Maintains information from running a command
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Report;
use Carp;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{platform}=shift;
    $self->{rv}=0;
    @{$self->{stdout}}=();
    @{$self->{stderr}}=();
    @{$self->{reports}}=();
    return $self;
}

sub platform {
    my $self=shift;
    return $self->{platform};
}

sub stdout {
    my $self=shift;
    return @{$self->{stdout}};
}

sub stderr {
    my $self=shift;
    return @{$self->{stderr}};
}

sub returnValue {
    my $self=shift;
    return $self->{rv};
}

sub addReport {
    my $self=shift;
    foreach my $rep ( @_ ) {
        croak("report::addReport() undefined report passed"), if( !defined $rep ); 
        croak("report::addReport() only objects of type Report can be passed : got ".(ref($rep))),
                if( ref($rep) ne "Report" ); 
        push @{$self->{reports}}, $rep;
    }
}

sub subReports {
   my $self=shift;
   return @{$self->{reports}};
}

sub failedReports {
   my $self=shift;
   my @reps=();
   foreach my $rep ( @{$self->{reports}} ) {
       if( $rep->returnValue() != 0 || $#{$self->{stderr}} != -1 ) {
          push @reps, $rep;
       } 
       push @reps, $rep->failedReports();
   }
   return @reps;
}

#
#  return non-zero if a report indicated failure
#
sub failed {
   my $self=shift;
   return 1, if $self->returnValue() !=0;
   return scalar $self->failedReports();
}

# ---- set methods

sub addStdout {
    my $self=shift;
    push @{$self->{stdout}}, @_;
}

sub addStderr {
    my $self=shift;
    push @{$self->{stderr}}, @_;
}

sub setReturnValue {
    my $self=shift;
    $self->{rv}=shift;
}
