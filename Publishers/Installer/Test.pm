# ----------------------------------
# class Publishers::Installer::Test
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Publishers::Installer::Test;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    return $self;
}

sub repositoryTypes {
    return qw(test);
}

sub installPackageCommand {
    my $self=shift;
    return "echo install @_";
}

sub uninstallPackageCommand {
    my $self=shift;
    return "echo remove @_";
}

sub updatePackageInfoCommand {
    my $self=shift;
    return "echo update";
}

sub addRepository {
    my $self=shift;
    my $platform=shift;
    my $repo=shift;

}

sub removeRepository {
    my $self=shift;
    my $platform=shift;
    my $repo=shift;
    my $release=shift;
}
