# ----------------------------------
# class rpmFiles
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Remote::rpmFiles;
use strict;
use File::DirectoryContent;
use FileHandle;
use Cwd;
1;

sub rpmFiles {
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

    if( defined $fileout ) {
        my $fh=FileHandle->new();
        $fh->open(">".$fileout) or die("unable to open file $fileout for output: $!");
        
        my $cont=File::DirectoryContent->new($dir);
        $cont->exclude(@_);
        for( ($cont->dirs()) ) {
            print $fh "%dir $_\n";
        }
        for( $cont->files() ) {
            print $fh "$_\n";
        }
        for( keys %{$cont->symlinks()} ) {
            print $fh "$_\n";
        }
        $fh->close();
    }
}
