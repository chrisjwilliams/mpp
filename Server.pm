# ----------------------------------
# class Server
# Description:
#    Base class for installating files on a server
# Abstracts away connection details etc.
#-----------------------------------
# Methods:
# new(INIConfig) :
# isRemote() : returns true if it is not the local machine
#-----------------------------------


package Server;
use strict;
use MppClass;
use FileHandle;
use RemoteFileHandle;
use File::Copy;
use Carp;
our @ISA=qw /MppClass/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    $self->{config}=shift;
    $self->{root}=$self->{config}->var("server","root");
    die "no root defined", if( ! defined $self->{root});
    die "illegal root '".($self->{root})."'", if( $self->{root}=~/\.\./ );
    if( ! -d $self->{root} ) {
       $self->_makedir( $self->{root} );
    }
    return $self;
}

sub isRemote  {
    my $self=shift;
    return ( defined $self->{server} );
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
            File::Copy::copy( $file , $dest) or  carp("Server: unable to copy file '$file' to $dest : $!");
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

    my @files;
    if( $self->isRemote() ) {
        # TODO
    }
    else {
        my $dh = DirHandle->new($dir) or die "$dir: $!\n";
        while (defined($_ = $dh->read)) {
            next, if( $_=~/^\.+/ );
            push @files, $_;
        }
    }
    return @files;
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
