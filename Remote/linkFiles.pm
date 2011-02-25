package Remote::linkFiles;
use strict;
1;

sub linkFiles {
    my $remoteApi=shift;
    my $target=shift;
    my $link=shift;

    # -- find common root between src and destination
    if( $target ne $link ) {
        my @texplode=split( /[\/\\]/, $target);
        my @lexplode=split( /[\/\\]/, $link);
        while ( defined $texplode[0] && defined $lexplode[0] 
            && $texplode[0] eq $lexplode[0] ) {
            shift @texplode; shift @lexplode;
        }
        my $tgt;
        if( $#texplode == 0 && $#lexplode > 0 )
        {
            # link is in a sub dir
            $tgt=("../" x ($#lexplode)).$lexplode[$#lexplode];
        }
        else {
            $tgt=join("/",@texplode);
        }
        symlink ( $tgt, $link ) or die "unable to create symlink '$link'->'$tgt' :$!";
    }
}
