# ----------------------------------
# class Publishers::Base
# Description:
#    Interface Definition and Utility methods for 
#    publishers
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Publishers::Base;
use strict;
use FileHandle;
use RemoteFileHandle;
use File::Copy;
use Package::Package;
1;


# ---- public interface ------------------
sub new {
    my $class=shift;
    my $config=shift;
    my $name=$config->{name} || "unnanmed";
    my $self={};
    bless $self, $class;
    $self->{config}=$config;
    $self->{root}=$self->{config}{root};
    die "illegal root '".($self->{root})."'", if( $self->{root}=~/\.\./ );
    $self->{verbose}=$self->{config}{verbose};
    die "no root defined", if( ! defined $self->{root});
    if( ! -d $self->{root} ) {
       $self->_makedir( $self->{root} );
    }
    return $self;
}

sub verbose {
    my $self=shift;
    if( defined $self->{verbose} ) {
        for ( @_ ) {
            print $self->type(),": ",$_,"\n";
        }
    }
}

sub type {
    my $self=shift;
    if( ! defined $self->{type} ) {
       ($self->{type}=ref($self))=~s/.*:://;
       $self->{type}=lc($self->{type});
    }
    return $self->{type};
}

sub name {
    my $self=shift;
    return $self->{config}{name};
}

sub add {
    my $self=shift;
    my $release=shift;
    my @packages=@_;

    print "add() method not implemented for ".ref($self)."\n";
}

sub remove {
    my $self=shift;
    my $release=shift;
    my $pkg=shift;
    print "remove() method not implemented for ".ref($self)."\n";
}

sub packageTypes {
    my $self=shift;
    die("packageTypes() method not implemented for ".ref($self)."\n");
}

# -- protected interface --

sub isRemote  {
    my $self=shift;
    return ( defined $self->{server} );
}

sub createDirs {
    my $self=shift;
    foreach my $dir ( @_ )
    {
        my $dir=$self->_file($dir);
        $self->_makedir( $dir );
    }
}

sub date {
    my $self=shift;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,
        $yday,$isdst)=localtime(time);
    return ($year+1900)."-".($mon+1)."-".$mday."-".$hour.":".$min.":".$sec;
}

sub removeTree {
    my $self=shift;
    my $dir=shift;

    $self->verbose("removing directory tree $dir");
    for( $self->listDir($dir) ) {
        if( -d $_ ) {
            $self->removeTree($_);
        }
        else {
            $self->removeFile($_);
        }
    }
    $self->removeFile($dir);
}

sub removeFile {
    my $self=shift;
    my $file=shift;

    $file=$self->_file($file);
    if( $self->isRemote() ) {
        $self->{server}->rmFile($file);
    }
    else {
        if( -f $file ) {
            $self->verbose("removing file $file");
            unlink $file or die "unable to remove $file : $!\n";
        }
        if( -d $file ) {
            $self->verbose("removing directory $file");
            rmdir $file or die "unable to remove $file : $!\n";
        }
    }
}

sub deleteIfEmpty {
    my $self=shift;
    my $dir=$self->_file(shift);
    my @files=$self->listDir($dir);
    if( $#files < 0 ) {
        $self->removeFile($dir);
    }
}

sub listDir {
    my $self=shift;
    my $dir=$self->_file(shift);

    my @files=();
    if( $self->isRemote() ) {
        # TODO
    }
    else {
        my $dh = DirHandle->new($dir) or die "$dir: $!\n";
        while (defined($_ = $dh->read)) {
            next, if( $_=~/^\.+/ );
            push @files, $dir."/".$_;
        }
    }
    return @files;
}

sub copyFile {
    my $self=shift;
    my $dest=pop @_;

    $dest=$self->{root}."/".$dest;
    if( $self->isRemote() ) {
        $self->{server}->upload(@_, $dest);
    }
    else {
        foreach my $file ( @_ ) {
            $self->verbose("Copying file '$file' to '$dest'");
            File::Copy::copy( $file , $dest) or  die("unable to copy file '$file' to $dest : $!");
        }
    }
}
#
# creates a directory
# independent of whether local or on a remote server
sub _makedir {
    my $self=shift;
    my $dir=shift;

    if( $self->isRemote() ) {
        $self->{server}->mkdir($dir);
    }
    else {
        if( ! -d $dir ) {
            mkdir( $dir, 0755) or die "unable to create dir $dir : $!\n";
        }
    }
}


#
# return a filehandle - either local or remote depending on
# the repository configuration
sub _fileHandle {
    my $self=shift;
    my $fh;
    if( $self->isRemote() ) {
        $fh=RemoteFileHandle->new($self->{server});
    }
    else {
        $fh=FileHandle->new();
    }
    return $fh;
}

sub _file {
    my $self=shift;
    my $file=shift;

    if( $file!~/^[\\\/]/ ) {
        $file=$self->{root}."/".$file;
    }
    return $file;
}
