# -----------------------------------------------
# Publishers::Apt
# -----------------------------------------------
# Description: 
# Apt repository management
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

package Publishers::Apt;
use File::Copy;
use File::Basename;
#use Digest::MD5::File qw( file_md5_hex );
use FileHandle;
use DirHandle;
use Debian::Package;
use Debian::Apt;
use Carp;
use strict;
use Publishers::Base;
our @ISA=qw /Publishers::Base/;
1;

# -- initialisation

sub new {
    my $class=shift;
    my $self = $class->SUPER::new(@_);
    bless $self, $class;
    $self->{deb}=Debian::Apt->new($self->{config});
    return $self;
}

sub packageTypes {
    return "deb";
}

sub repositoryRefs {
    my $self=shift;
    my $platform=shift; # platform name
    my $type=shift;

    my @urls=();
    my @platforms;
    if( defined $platform ) {
        push @platforms,$platform;
    }
    else {
        @platforms=$self->{deb}->platforms();
    }
    foreach my $release ( @platforms )
    {
        my @types=(defined $type)?($type):$self->{deb}->types($release);
        foreach my $type ( @types )
        {
            push @urls, $self->{deb}->repositoryRefs( $release, $type );
        }
    }
    return @urls;
}

sub add {
    my $self=shift;
    my $release=shift;
    my @packages=@_;

    for(@packages) {
        my $platform=$_->platform();
        foreach my $packageFile ( $_->packageFiles() ) {
            if( -f $packageFile )
            {
                $self->verbose("adding file $packageFile");
                my $package=Debian::Package->new($packageFile);
                $self->{deb}->add($platform, $release, $package );
            }
            else {
                croak("File '".$packageFile."' does not exist");
            }
        }
    }
}

sub remove {
    my $self=shift;
    my $release=shift;
    my @packages=@_;

    for(@packages) {
        my $platform=$_->platform();
        foreach my $pkg ( $_->packageFiles() ) {
            $self->{deb}->remove($platform, $release, basename($pkg) );
        }
    }
}

sub architectures {
    my $self=shift;
    my $platform=shift;

    return $self->{deb}->architectures($platform, $self->{deb}->types($platform));
}

#sub AUTOLOAD {
#    my $self = shift;
#    return if our $AUTOLOAD =~ /::DESTROY$/;
#    my $name=$AUTOLOAD;
#    $name =~ s/.*://;   # strip fully-qualified portion
#
#    return ($self->{deb}->$name());
#}
