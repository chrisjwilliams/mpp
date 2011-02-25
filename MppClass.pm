# ----------------------------------
# class MppClass
# Description:
#    Base functionality for MPP classes
#-----------------------------------
# Methods:
# new() :
# setVerbose(int) : set verbosity level (0 or 1)
# vebose(@messages)
#-----------------------------------


package MppClass;
use strict;
1;

sub new {
    my $class=shift;
    my $config=shift;
    my $self={};
    $self->{verbose}=0;
    bless $self, $class;
    if($config) {
        for($config->vars("verbose")) {
            if( $class eq $_ ) {
                $self->{verbose}=$config->var("verbose",$_); 
                last;
            }
        }
        $self->{config}=$config;
    }
    $self->{verbosePrefix}=ref($self).": ";
    return $self;
}

sub setVerbose {
    my $self=shift;
    $self->{verbose}=shift||0;
}

sub verbose {
    my $self=shift;
    if( $self->{verbose} > 0 ) {
        print $self->{verbosePrefix};
        for(@_){
            print $_,"\n";
        }
    }
}
