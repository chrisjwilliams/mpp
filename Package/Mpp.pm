# ----------------------------------
# class Package::Mpp
# Description:
#    Manipulation of an Mpp's native
#    package format. 
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Package::Mpp;
use Package::Package;
use strict;
our @ISA = qw/Package::Package/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    $self->{config}=shift;
    return $self;
}

sub save {
    my $self=shift;
    my $fh=shift;
}

#
# these will be tarred up somehow (platform dependent)
#
#sub unpack {
#    my $self=shift;
#    $self->{platform}->unpack($self->{compressedFile});
#}

#sub pack {
#    my $self=shift;
#    my $dir=shift;

#    my $mppfile=$dir."/".$self->_mppfile();
#    if( ! -f $mppdir ) {
#        $self->_generateMpp($mppfile);
#    }
#    $self->{platform}->packup($dir);
#}

#sub install {
#    my $self=shift;
#    my $root=shift;

    #
    # lock
    #

    #
#    $self->unpack($root);
    # add to list of installed packages

    # unlock
#}
#
#sub _generateMpp() {
#    my $self=shift;
#    my $file=shift;
#    $self->{config}->write($file);
#}
