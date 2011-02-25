package Remote::listDir;
use strict;
use File::DirectoryContent;
use FileHandle;
use Cwd;
1;

sub listDir {
    my $remoteApi=shift;
    my $fileout;
    while( $_[0]=~/^-(.*)/ ) {
        shift @_;
        if($1 eq "f" ) {
            $fileout=shift @_;
            next;
        }
    }
    my $dir=shift @_;
    if( $dir!~/^[\\\/]/ )
    {
        $dir=getcwd()."/".$dir;
    }
    my @files=directoryFiles( $dir, @_);
    if( defined $fileout ) {
        my $fh=FileHandle->new();
        $fh->open(">".$fileout) or die("unable to open file $fileout for output: $!");
        foreach my $file ( @files ) {
            print $fh $file,"\n";
        }
    }
    else {
        return @files;
    }
}

sub directoryFiles {
    my $dir=shift;
    my @exclude=@_;

    my $content=File::DirectoryContent->new($dir);
    $content->exclude(@exclude);
    my @files=$content->files();
    return (sort(@files));
}
