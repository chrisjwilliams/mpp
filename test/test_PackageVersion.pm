# ----------------------------------
# class test_PackageVersion
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_PackageVersion;
use PackageVersion;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    return $self;
}

sub tests {
    return qw( test_version );
}

sub test_version {
    my $self=shift;

    PackageVersion v0(0.0.0);
    {
        # Use Case : 0.0.0 version
        # Expect   : 3 components
        my @components=$v0->components();
        die("expecting 0 components") , if( scalar @omponents );
    }
    {
        # Use Case : an empty string
        # Expect   : no components, everything should be > than this
        PackageVersion v;
        die("expecting 0 components") , if( v->components() != -1 );
        die("expecting anything to be > than an undefined version"), if( ! (v0 > v ) );
    }
}

