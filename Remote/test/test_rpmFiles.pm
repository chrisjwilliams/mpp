# ----------------------------------
# class test_rpmFiles
# Description:
# unit test for the linkfiles subroutine
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_rpmFiles;
use Remote::rpmFiles;
use FileHandle;
use File::Sync qw/sync/;
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
    return qw( test_full test_exclude test_excludeall );
}

sub test_full {
    my $self=shift;
    my $dir=$self->{tmpdir}."/a";
    my $file=$self->{tmpdir}."/fileOut_full";
    Remote::rpmFiles::rpmFiles({}, "-f", $file, $dir );
    my @expect=sort("%dir /b", "%dir /b/c", "%dir /b/c/d",qw(/file /filea /b/file /b/c/file /b/c/d/file /b/fileb /b/c/filec /b/c/d/filed));
    sync();
    die( "file $file not created"), if ( ! -f $file );
    my $fh=FileHandle->new("<".$file) or die "ugh opening $file";
    my @files=<$fh>;
    my $exp=join("\n", @expect)."\n";
    my $files=join('',@files);
    die("expecting $exp, get $files"), if( $exp ne $files );
}

sub test_exclude {
    my $self=shift;
    my $dir=$self->{tmpdir}."/a";
    my $exclude="/b/c/d";
    my @expect=sort("%dir /b", "%dir /b/c",qw(/file /filea /b/file /b/fileb /b/c/file /b/c/filec));
    my $file=$self->{tmpdir}."/fileOut_exclude";
    Remote::rpmFiles::rpmFiles({}, "-f", $file, $dir, $exclude );
    sync();
    die( "file $file not created"), if ( ! -f $file );
    my $fh=FileHandle->new("<".$file) or die "ugh opening $file";
    my @files=<$fh>;
    my $exp=join("\n", @expect)."\n";
    my $files=join('',@files);
    die("expecting $exp, get $files"), if( $exp ne $files );
}

sub test_excludeall {
    my $self=shift;
    my $dir=$self->{tmpdir}."/a";
    my $exclude="/";
    my $file=$self->{tmpdir}."/fileOut_excludeAll";
    Remote::rpmFiles::rpmFiles({}, "-f", $file, $dir, $exclude );
    sync();
    die( "file $file not created"), if ( ! -f $file );
    my $fh=FileHandle->new("<".$file) or die "ugh opening $file";
    my @files=<$fh>;
    my $exp="";
    my $files=join('',@files);
    die("expecting $exp, get $files"), if( $exp ne $files );
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
