package Remote::cleanLinks;
use strict;
use Cwd;
1;

sub cleanLinks {
    my $remoteApi=shift;
    my $dir=shift;

    require File::DirIterator;
    my $it=File::DirIterator->new($dir);
    $it->includeDirs();
    if( $dir!~/^[\\\/]/ )
    {
        $dir=getcwd()."/".$dir;
    }
    while( defined ($_=$it->next()) ) {
        if( -l $_ ) {
            my $pos=readlink $_;
            $pos=~s/^$dir([\\\/].*)/$1/;
            unlink $_;
            symlink ($pos, $_) or die "unable to creat symlink $pos $_";
        }
    }
}
