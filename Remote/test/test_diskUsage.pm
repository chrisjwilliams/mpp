# ----------------------------------
# class test_diskUsage
# Description:
# unit test for the linkfiles subroutine
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_diskUsage;
use Remote::diskUsage;
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
    return qw( test_full test_exclude test_excludeall);
}

sub test_full {
    my $self=shift;
    my $dir=$self->{tmpdir}."/a";
    my $size=Remote::diskUsage::diskUsage({}, $dir );
    die "got $size bytes", if ($size != 12788);
    #system("du -ab $dir");
}

sub test_exclude {
    my $self=shift;
    my $dir=$self->{tmpdir}."/a";
    my $exclude=$self->{tmpdir}."/a/b/c";
    my $size=Remote::diskUsage::diskUsage({}, $dir, $exclude );
    die "got $size bytes", if ($size != 4338);
}

sub test_excludeall {
    my $self=shift;
    my $dir=$self->{tmpdir}."/a";
    my $exclude=$self->{tmpdir}."/a";
    my $size=Remote::diskUsage::diskUsage({}, $dir, $exclude );
    die "got $size bytes", if ($size != 0);
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
