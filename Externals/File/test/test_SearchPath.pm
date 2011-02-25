# ----------------------------------
# class test_SearchPath
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_SearchPath;
use File::SearchPath;
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
    return qw( test_add test_search test_init test_cleanPath);
}

sub test_add {
    my $self=shift;
    my @dirs=( "/local/some/path", "/local/", "/local/../some/other/path", "/local/../some/other/..", "/local/../some/..", "relative/path" );
    my $sp=File::SearchPath->new();
    $sp->add(@dirs);
    my @exp=$sp->paths();
    die "expecting /local/some/path got $exp[0]", if ( $exp[0] ne "/local/some/path");
    die "expecting /local $exp[1]", if ( $exp[1] ne "/local");
    die "expecting /some/other/path got $exp[2]", if ( $exp[2] ne "/some/other/path");
    die "expecting /some got $exp[3]", if ( $exp[3] ne "/some");
    die "expecting / got $exp[4]", if ( $exp[4] ne "/");
    die "expecting expanded path got $exp[5]", if ( $exp[5] !~ "^[\\\/].*relative/path");
    $sp->add("..");
}

sub test_search {
    my $self=shift;
    my @dirs;
    my $t1="testFile1";
    my $d1=$self->{tmpdir}."/dir1";
    mkdir $d1 or die "unable to create dir $d1 : $!";
    my $d2=$self->{tmpdir}."/dir2";
    mkdir $d2 or die "unable to create dir $d1 : $!";
    my $d3=$self->{tmpdir}."/dir3";
    mkdir $d3 or die "unable to create dir $d1 : $!";
    my $d4=$self->{tmpdir}."/Idonotexist";
    my $test1=$d1."/$t1";
    my $test2=$d3."/$t1";
    $self->_touch($test1);
    $self->_touch($test2);

    my $sp=File::SearchPath->new();
    $sp->add( $d1, $d2, $d3, $d4 );
    my @exp=$sp->find( $t1 );
    die "expecting $test1 got $exp[0]", if ( $exp[0] ne $test1);
    die "expecting $test2 got $exp[1]", if ( $exp[1] ne $test2);
    @exp=$sp->find( "nontHere" );
    die "expecting empty list got @exp", if ( $#exp >= 0 );

}

sub test_init {
    my $self=shift;
    my $sp=File::SearchPath->new( "/local:/charlie" );
    my @exp=$sp->paths();
    die "expecting /local got $exp[0]", if ( $exp[0] ne "/local");
    die "expecting /charlie $exp[1]", if ( $exp[1] ne "/charlie");
}

sub test_cleanPath {
    my $self=shift;
    {
        # case 1 : no special characters
        my $in="/wibble/wooble";
        my $out=File::SearchPath::cleanPath($in);
        die("expecting '$out', got '$in')"), if ( $out ne $in );
    }
    {
        # case 2 : double seperator
        my $in="/wibble//wooble";
        my $out=File::SearchPath::cleanPath($in);
        my $exp="/wibble/wooble";
        die("expecting '$out', got '$exp')"), if ( $out ne $exp );
    }
    {
        # case 3 : .. in path
        my $in="/wibble/../wooble";
        my $out=File::SearchPath::cleanPath($in);
        my $exp="/wooble";
        die("expecting '$exp', got '$out')"), if ( $out ne $exp );
    }
    {
        # case 3 : double .. in path
        my $in="/wibble/wobble/../../woo";
        my $out=File::SearchPath::cleanPath($in);
        my $exp="/woo";
        die("expecting '$exp', got '$out')"), if ( $out ne $exp );
    }
    {
        # case 4 : .. at end of path
        my $in="/wibble/wooble/..";
        my $out=File::SearchPath::cleanPath($in);
        my $exp="/wibble";
        die("expecting '$exp', got '$out')"), if ( $out ne $exp );
    }
}

sub _touch {
    my $self=shift;
    my $file=shift;
    my $fh=FileHandle->new();
    $fh->open(">".$file) or die "cannot create file $file: $!";
    print $fh $file, "\n";
    $fh->close();
}
