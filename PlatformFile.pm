# ----------------------------------
# class PlatformFile
# Description:
#   Describes a file on a specific 
#   platform
#-----------------------------------
# Methods:
# new(filename,Platform) :
# fileHandle("<"|">" [, rootdir]) : open a new filehandle - relative to root if supplied)
#-----------------------------------

package PlatformFile;
use RemoteFileHandle;
use FileHandle;
use Carp;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{filename}=shift;
    $self->{platform}=shift;
    if( defined $self->{platform} ) {
        croak("expecting a Platform object"), if( ! $self->{platform}->isa("Platform") );
    }
    return $self;
}


sub fullFileName {
    my $self=shift;
    my $root=shift || "";
    die("bad root $root"), if ( $root!~/^[\\\/].*/ && $root ne "" );
    if ( $root=~/\/$/ ) {
        chop $root;
    }
    my $fn=$root.$self->{filename};
    #print "filename: $fn\n";
    return $fn;
}


sub platform {
    my $self=shift;
    return $self->{platform}
}

sub fileHandle {
    my $self=shift;
    my $type=shift;
    my $root=shift;
    if( ! defined $type || ($type ne "<" && $type ne ">") ) {
        die "filehandle type badly or not defined ( only \">\" or \"<\" )";
    }
    my $fh;
    if( defined $self->{platform} ) {
        $fh=RemoteFileHandle->new($self->{platform});
    }
    else {
        $fh=FileHandle->new();
    }
    my $fn=$self->fullFileName($root);
    $fh->open($type.$fn) or die("unable to open '$fn' in mode '$type' (".(ref($fh)).") : $!");
    return $fh;
}

