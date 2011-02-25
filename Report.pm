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
        $self->{count}=0;
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
        croak("report::addReport() report objects only can be passed -get ".(ref($rep))),
                if( ref($rep) ne "Report" ); 
        push @{$self->{reports}}, $rep;
        print "count=",++$self->{count},"\n";
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
