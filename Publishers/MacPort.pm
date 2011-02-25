# ----------------------------------
# class Publishers::MacPort
# Description:
#    Repository for MacPorts PortFiles
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Publishers::MacPort;
use strict;
use Publishers::Base;
our @ISA=qw /Publishers::Base/;
1;

sub new {
    my $class=shift;
    my $self = $class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub add {
    my $self=shift;
    my $release=shift;
    my @packages=@_;

    my $port;
    for(@packages) {
        my $platform=$_->platform();
        my $dir=$platform."/".$release;
        foreach my $package ( $_->packageFiles() ) {

            if( defined $package && $package ne "" ) {
                if( $package=~/Portfile/g )
                $port=MacPort::PortFile->new($package);
            }
            else {
                push @srcs, $package;
            }
        }
        if( defined $port ) {
            my $arch=$port->arch();

            # -- ensure the structure exists
            my $archdir=$platform."/".$release."/".$arch;
            $self->createDirs($platform, $dir, $archdir);

            # -- copy in the src files
            $self->copyFile($portfile, $archdir );

            # -- create the portfile
            $port->addDownload($serverUrl."/".$src);
            $port->write($fh);

        }
    }
    $self->_createindex($dir);
}

sub remove {
    my $self=shift;
    my $release=shift;
    my $pkg=shift;

    my @packages=@_;

    for(@packages) {
        my $platform=$_->platform();
        my $dir=$platform."/".$release;
        my $arch=$_->arch();
        my $archdir=$dir."/".$arch;
        foreach my $pkg ( $_->packageFiles() ) {
            my $pkgFile=$archdir."/".$pkg;
            $self->removeFile($pkgFile);
        }
        # -- clean up directory if empty
        $self->deleteIfEmpty($archdir);
    }
}

sub architectures {
    my $self=shift;
    my $platform=shift;

    my %archs;
    foreach my $release ( @_ ) {
        my $dir=$self->{root}."/".$platform."/".$release;
        my @dirs=$self->listDir($dir);
        foreach my $d ( @dirs ) {
            next, if( $d=~/^\.+/ );
            $archs{$d}=$d;
        }
    }
    return ( keys %archs );
}

sub _createindex {
    my $self=shift;
    my $dir=shift;

}
