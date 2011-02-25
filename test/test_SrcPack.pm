# ----------------------------------
# class test_SrcPack
# Description:
#    unit tests for the SrcPack object
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package test_SrcPack;
use SrcPack;
use TestUtils::TestPackage;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{tpack}=TestUtils::TestPackage->new($self->{testConfigDir},$self->{tmpdir});
    return $self;
}

sub tests {
    return qw( test_cleanup test_type test_repack test_patch);
}

sub test_type {
    my $self=shift;
    my $srcpack=$self->_srcPack();
    my $type=$srcpack->type();
    my $expect="tar";
    die("wrong type - expecting $expect got $type"), if( $expect ne $type );
}

sub test_repack {
    my $self=shift;
    my $srcpack=$self->_srcPack();
    #
    # We test if we can unpack and repackage the file
    #
    my $tmpdir=$self->{tmpdir}."/repack";
    mkdir $tmpdir;
    my $dir=$srcpack->_unpack($tmpdir, $srcpack->rawPackage() );
    my $expectdir=$tmpdir."/src";
    die("expecting unpacked dir in $expectdir, got $dir"), if( $expectdir ne $dir );
    $srcpack->_repack($tmpdir);
    my $file=$srcpack->packageFile();
    die("file $file does not exist"), if( ! -f $file );
    my $expectedfile=$tmpdir."/testproject_src.tar";
    die("got file $file, expecting $expectedfile"), if( $file ne $expectedfile );
    my $orig=$srcpack->rawPackage();
    die("expecting repackaged file name, got the original $orig"), if( $file eq $orig);
}

sub test_patch {
    my $self=shift;
    my $srcpack=$self->_srcPack();
    my $patch=$self->{testConfigDir}."/test_project/patch1.patch";
    die("unable to find patch file $patch"), if ( ! -f $patch );
    $srcpack->patch($patch);
    my $file=$srcpack->packageFile();
    my $orig=$srcpack->rawPackage();
    die("expecting repackaged file name, got the original $orig"), if( $file eq $orig);
    my $tdir=$srcpack->{tmp};
    undef $srcpack;
    die("workdir $tdir not cleaned up"), if( -d $tdir ); 
}

sub test_cleanup {
    my $self=shift;
    my $tmpdir;
    {
        my $srcpack=$self->_srcPack();
        $tmpdir=$srcpack->{tmp};
        die("workdir $tmpdir does not exist"), if( ! -d $tmpdir ); 
    }
    die("workdir $tmpdir not cleaned up"), if( -d $tmpdir ); 
}

sub _srcPack {
    my $self=shift;
    my $tarfile=$self->{tpack}->tar();
    my $config={ srcDirectory=>"src",
                 srcPack=>$tarfile
    };
    return SrcPack->new($config);
}
