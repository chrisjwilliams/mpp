# -----------------------------------------------
# Test
# -----------------------------------------------
# Description: 
#    A dummy publisher for testing purposes
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

package Publishers::Test;
use File::Copy;
use File::Basename;
use FileHandle;
use DirHandle;
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
}

sub remove {
    my $self=shift;
    my $release=shift;
    my $pkg=shift;
}

sub architectures {
    my $self=shift;
    my $release=shift;
}

sub installPackageCommand {
    my $self=shift;
}

sub uninstallPackageCommand {
    my $self=shift;
}

sub updatePackageInfo {
    my $self=shift;
}
# -- private methods -------------------------
