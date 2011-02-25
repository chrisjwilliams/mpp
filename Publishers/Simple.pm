# -----------------------------------------------
# Simple
# -----------------------------------------------
# Description: 
# Simple directory management
#
#
# -----------------------------------------------
# Copyright Chris Williams 2008
# -----------------------------------------------
# Interface
# ---------
# new()    : new object
#
#

package Publishers::Simple;
use File::Copy;
use File::Basename;
use FileHandle;
use DirHandle;
use Carp;
use strict;
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self={};
    bless $self, $class;
    $self->{config}=shift;
    $self->{root}=$self->{config}->{root};
    if( ! defined $self->{root} || $self->{root} eq "" ) {
        die( "root not set for simple repository" );
    }
    $self->_construct();

    return $self;
}

sub addRepository {
}

sub packageTypes {
    return "deb";
}

sub repositoryRefs {
    my $self=shift;
    my $release=shift;
    my $type=shift;

    my $url=$self->{root}."/".$release."/".$type;
    return $url;
}

sub add {
    my $self=shift;
    my $platform=shift;
    my $release=shift;
    my $packageFile=shift;
    if( -f $packageFile )
    {
        my $dir="/pool";
        my $rdir=$dir."/".$release;
        $self->_mkdirs($dir,$rdir);

        # -- copy file into the repository
        # make filename consistent with control info
        my $dest=basename($packageFile);
        copy($packageFile, $self->{root}.$dir."/".$dest ) or die("unable to copy file $packageFile $!\n");
    }
    else {
        croak("File '".$packageFile."' does not exist");
    }
}

sub remove {
    my $self=shift;
    my $release=shift;
    my $pkg=shift;

    my $pool="/pool";
    my $rdir="/dists/$release";
    # -- remove the pkg files
    unlink $self->{root}.$rdir."/".$pkg or die $pkg." does not exist\n";
}

sub architectures {
    my $self=shift;
    my $release=shift;
}

sub locate {
    my $self=shift;
    my $search={};

    if( defined $search->{name} )
    {
    }
}

# -- private methods -------------------------

sub _mkdirs {
    my $self=shift;
    foreach my $dir ( @_ )
    {
        my $dir=$self->{root}.$dir;
        if( ! -d $dir )
        {
            mkdir( $dir, 0755) or die "unable to create dir $dir : $!\n";
        }
    }
}

sub _construct {
    my $self=shift;
    my $release=shift;

    # -- deb files live in the pool directory
    #    are seperated in to letter named dirs. lib packages
    #    are treated differently in that the lib and fist letter marks the dir
    #    a dir with the package name, with the debs underneath
    if( ! -d $self->{root} ) {
       mkdir( $self->{root}, 0755) 
                   or die ("unable to make ".$self->{root}." $!\n");
    }
    my $pool="/pool";
    $self->_mkdirs( $pool);
}
