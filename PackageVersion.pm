# ----------------------------------
# class PackageVersion
# Description:
#    class to manipulate and test package version numbers
#-----------------------------------
# Methods:
# new(verison string) :
# operator >          ; retuns true if the specified version is greater thand this current
# setVersion(string)  :
#-----------------------------------


package PackageVersion;
use overload ">" => \&_greaterThan;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    @{$self->{versions}}=();
    $self->setVersion(shift);
    return $self;
}

sub versionString {
    my $self=shift;
    return $self->{string};
}


sub setVersion {
    my $self=shift;
    $self->{string}=shift;
    if( defined $self->{string} ) {
        foreach my $d ( split(/\./,$self->{string}) ) {
            # extract the digit part of any version id
            (my $digits=$d)=~s/[^\d.]//g;
            push @{$self->{versions}}, $digits;
        }
    }
}

sub components {
    my $self=shift;
    return @{$self->{versions}};
}

sub _greaterThan {
    my $self=shift;
    my $version=shift;
    # -- anything should be > than an undefined version
    return 0, if( ! defined $self->{string} );
    return 1, if( ! defined $version->{string} );

    my $size=scalar @{$self->{versions}};
    my $vsize=scalar @{$version->{versions}};
    # -- check each component in turn
    for(my $i=0; $i< $vsize; ++$i ) {
        if( $size <= $i ) { return 0; };
        if( $version->{versions}[$i] < $self->{versions}[$i] ) {
            return 1;
        }
    }
    # -- check any extra digits
    if( $size > $vsize ) { 
        for(my $i=$vsize; $i<$size; ++$i ) {
            return 1, if( $self->{versions}[$i] != 0 );
        }
    };
    return 0;
}
