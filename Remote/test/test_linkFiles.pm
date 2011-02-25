# ----------------------------------
# class test_linkFiles
# Description:
# unit test for the linkfiles subroutine
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_linkFiles;
use Remote::linkFiles;
use FileHandle;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->_createStucture();
    return $self;
}

sub tests {
    return qw( test_identical test_sameDir test_subdirLink test_parentdirLink );
}

sub test_identical {
    # expect: silently ignore
    my $self=shift;
    my $dir=$self->{tmpdir}."/a/b/file";
    Remote::linkFiles::linkFiles({}, $dir, $dir );
}

sub test_sameDir {
    # expect: silently ignore
    my $self=shift;
    my $dir=$self->{tmpdir}."/a/b/file";
    my $link=$self->{tmpdir}."/a/b/file_link";
    Remote::linkFiles::linkFiles({}, $dir, $link );
    die "link not created", if ( ! -l $link );
    my $pos=readlink $link;
    die "expecting 'file' got $pos", if ( $pos ne 'file' );
}

sub test_subdirLink {
    # expect: silently ignore
    my $self=shift;
    my $dir=$self->{tmpdir}."/a/b/file";
    my $link=$self->{tmpdir}."/a/b/c/file_link";
    Remote::linkFiles::linkFiles({}, $dir, $link );
    die "link not created", if ( ! -l $link );
    my $pos=readlink $link;
    die "expecting '../file' got $pos", if ( $pos!~/..[\\\/]file/ );
}

sub test_parentdirLink {
    # expect: silently ignore
    my $self=shift;
    my $dir=$self->{tmpdir}."/a/b/file";
    my $link=$self->{tmpdir}."/a/file_link";
    Remote::linkFiles::linkFiles({}, $dir, $link );
    die "link not created", if ( ! -l $link );
    my $pos=readlink $link;
    die "expecting 'b/file' got $pos", if ( $pos!~/b[\\\/]file/ );
}

sub _createStucture {
    my $self=shift;
    my $d=$self->{tmpdir};
    # make a/b/c/d hierarcy
    foreach my $dir ( qw(a b c d) ) {
        $d.="/".$dir;
        mkdir $d or die "unable to create dir $d\n";
        my $file=$d."/file"; # identically named file in each dir
        $self->_touch($file);
        my $ufile=$d."/file".$dir; # uniquely named file in each dir
        $self->_touch($ufile);
    }
}

sub _touch {
    my $self=shift;
    my $file=shift;
    my $fh=FileHandle->new(">".$file) or die("error creating file $file : $!");
    print $fh "Filename: $file\n";
    $fh->close();
    return $file;
}
