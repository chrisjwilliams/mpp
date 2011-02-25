# ----------------------------------
# class Publishers::Installer::Base
# Description:
#   Base class for all Installers
#-----------------------------------
# Methods:
# new() :
# addRepository()
#
# Abstract Interface Methods:
# ---------------------------
# packageTypes() return list of package types to handle
# repositoryTypes() : return list of Publishers able to interact with
# addRepositoryProcedure() : Define the procedure to add a repository
# removeRepository(Publisher, release_level)
#-----------------------------------

package Publishers::Installer::Base;
use SysProcedure::Procedure;
use SysProcedure::File;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{platform}=shift;
    bless $self, $class;
    return $self;
}

sub addRepository {
    my $self=shift;
    my $log=shift;
    if( ! $log->isa("GLOB") )
    {
        unshift @_, $log;
        $log = undef;
    }
    my $proc=$self->addRepositoryProcedure(@_);
    $proc->execute($log,"/"), if defined $proc;
}

# Required Interface To be implemented
sub packageTypes {
    return ();
}

sub repositoryTypes {
    return ();
}

sub updatePackageInfoCommand {
    my $self=shift;
    my @repositories=shift; # Publisher Object
}

sub installPackageCommand {
    my $self=shift;
    my @packages=@_; # list of PackageInfo objects
    return undef;
}

sub uninstallPackageCommand {
    my $self=shift;
    my @packages=@_; # list of PackageInfo objects
    return undef;
}

sub addRepositoryProcedure {
    my $self=shift;
    my $repository=shift; # Publisher Object
    my $release=shift;
    my $proc=new SysProcedure::Procedure;
    return $proc;
}

sub removeRepository {
    my $self=shift;
    my $repository=shift; # Publisher Object
    my $release=shift;
}
