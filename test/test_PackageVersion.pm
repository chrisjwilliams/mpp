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

    my $v0=PackageVersion->new("0.0.0");
    {
        # Use Case : 0.0.0 version
        # Expect   : 3 components, > should return false
        my @components=$v0->components();
        die("expecting 3 components got ".(scalar @components)) , if( scalar @components != 3 );
        die("not expecting > for identical versions"), if( $v0 > $v0 );
    }
    {
        # Use Case : an empty string
        # Expect   : no components, everything should be > than this
        my $v=new PackageVersion;
        my @components=$v->components();
        die("expecting no components got ".(scalar @components)." @components" ) , if( $v->components() != 0 );
        die("expecting anything to be > than an undefined version"), if( $v > $v0 );
        die("expecting anything to be > than an undefined version"), if( ! ($v0 > $v ) );
    }
    {
        # Use Case : a version number same as 0.0.0 with the same number of components
        # Expect   : should not be > 
        my $v=new PackageVersion("0.0.0");
        die("not expecting > for identical versions"), if( ($v0 > $v ) );
        die("not expecting > for identical versions"), if( ($v > $v0 ) );
    }
    {
        # Use Case : a version number same as 0.0.0 with two components
        # Expect   : should not be > 
        my $v=new PackageVersion("0.0");
        die("not expecting > for identical versions"), if( ($v0 > $v ) );
        die("not expecting > for identical versions"), if( ($v > $v0 ) );
    }
    {
        # Use Case : a version number same as 0.0.0 with the only one component
        # Expect   : should not be > 
        my $v=new PackageVersion("0");
        die("not expecting > for identical versions"), if( ($v0 > $v ) );
        die("not expecting > for identical versions"), if( ($v > $v0 ) );
    }
    {
        # Use Case : a version number greater than 0.0.0 with the same number of components
        # Expect   : should be > 
        my $v=new PackageVersion("0.0.1");
        die("not expecting 0.0.0 >  0.0.1"), if( $v0 > $v );
        die("expecting 0.0.1 > 0.0.0"), if( ! ($v > $v0 ) );
    }
    {
        # Use Case : a version number greater than 0.0.0 with the more components
        # Expect   : should be > 
        my $v=new PackageVersion("0.0.0.1");
        die("not expecting 0.0.0 >  0.0.0.1"), if( $v0 > $v );
        die("expecting 0.0.0.1 > 0.0.0"), if( ! ($v > $v0 ) );
    }
    {
        # Use Case : a version number greater than 0.0.0 with 2 components
        # Expect   : should be > 
        my $v=new PackageVersion("0.1");
        die("not expecting 0.0.0 >  0.1"), if( $v0 > $v );
        die("expecting 0.1 > 0.0.0"), if( ! ($v > $v0 ) );
    }
    {
        # Use Case : a version number greater than 0.0.0 with 1 components
        # Expect   : should be > 
        my $v=new PackageVersion("1");
        die("not expecting 0.0.0 >  1"), if( $v0 > $v );
        die("expecting 1 > 0.0.0"), if( ! ($v > $v0 ) );
    }
    {
        # Use Case : a version number that is greater containing a non numeric part greater than 0.0.0
        # Expect   : should be > 
        my $v=new PackageVersion("0.svn5689");
        die("not expecting 0.0.0 >  0.svn5689"), if( $v0 > $v );
        die("expecting  0.svn5689 > 0.0.0"), if( ! ($v > $v0 ) );
    }
    {
        # Use Case : a version number that is greater containing a non numeric part greater than 0.0.0
        # Expect   : should be > 
        my $v=new PackageVersion("svn5689");
        die("not expecting 0.0.0 >  svn5689"), if( $v0 > $v );
        die("expecting  svn5689 > 0.0.0"), if( ! ($v > $v0 ) );
    }
}

