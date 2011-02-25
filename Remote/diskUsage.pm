package Remote::diskUsage;
use strict;
use File::DirIterator;
use Cwd;
1;

sub diskUsage {
    my $remoteApi=shift;
    my $dir=shift;
    my @exclude=@_;

    my $it=File::DirIterator->new($dir);
    $it->includeDirs();
    my $i;
    for ( $i=0; $i<=$#exclude; $i++ )
    {
        if( $exclude[$i]!~/^[\\\/]/ ) {
            $exclude[$i]=getcwd()."/".$exclude[$i];
        }
    }
    if( $dir!~/^[\\\/]/ )
    {
        $dir=getcwd()."/".$dir;
    }
    my $count=0;
    my $file;
    while( defined ($file=$it->next()) ) {
        my $found=0;
        foreach my $ex ( @exclude ) {
            if( $file=~m/$ex/ ) {
                $found=1; last;
            }
        }
        if( ! $found ) {
            $count+=(-s $file);
        }
    }
    return $count;
}
