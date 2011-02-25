# ----------------------------------
# class MacOSX
# Description:
#    The Mac OSX specific setup
#-----------------------------------
# Methods:
# new() :
# resetDisk()
#-----------------------------------

package Platforms::MacOSX;
use strict;
use Platform;
our @ISA=qw /Platform/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    $self->{hdiutil}="/usr/bin/hdiutil";
    return $self;
}

sub getFetchURLCmd {
    my $self=shift;
    my $localcache=shift;
    my @urls=@_;
    my $cmd=$self->{config}{commands}{curl} || "/usr/bin/curl";
    $cmd="cd $localcache; ".$cmd;
    return $cmd;
}

sub hasOverlay {
    return 1;
}

sub setupOverlay {
    my $self=shift;
    my $name=shift;
    my $log=shift;

    my $overlay="mpp_overlay_$name";
    if( ! defined $self->{overlays}{$overlay} ) {
        # find info about the diskImage
        my $image=$self->cleanImageMount();
        die( "[workspace] diskImage not defined for mounting" ), if( ! defined $image );
        my $size=$self->{config}->var("workspace","diskImageSize");
        die( "[workspace] diskImageSize not defined for mounting" ), if( ! defined $size);

        # -- setup the union fs
        # first create a sparse disk image
        my $hdiutil=$self->{hdiutil};
        my $overlayfile=$self->{workdir}."/".$overlay.".sparseimage";
        if( ! $self->fileExists($overlayfile) ) {
            $self->verbose("creating overlay $overlayfile");
            my $cmd=$hdiutil." create $overlayfile -volname $overlay -size $size -type SPARSE -fs HFS+J";
            $self->invoke($cmd,$log);
            $self->{overlays}{$overlay}=0; # image created
        }

        # mount the overlay over our clean disk image
        #my $mount=$self->{workdir}."/".$overlay."_mnt";
        #$self->mkdir("mpp",$mount);
        my $cmd="sudo ".$hdiutil." attach $overlayfile -private -readwrite -mountpoint $image -union";
        $self->verbose("mounting overlay $overlayfile on $image");
        $self->invoke($cmd,$log);
        $self->{overlays}{$overlay}=$image; # image mounted
    }
}

sub _unmountOverlays {
    my $self=shift;
    my $log=shift;
    for(keys %{$self->{overlays}}) {
        my $cmd=$self->{hdiutil}." detach ".$self->{overlays}{$_};
        $self->invoke($cmd,$log);
    }
}

sub DESTROY {
    my $self=shift;
    #$self->_unmountOverlays();
}
