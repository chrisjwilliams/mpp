# ----------------------------------
# class Publishers::Installer::MacPort
# Description:
#  Install packages prom an MacPort repository
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Publishers::Installer::MacPort;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    return $self;
}

sub repositoryType {
    return qw(macport);
}

sub installPackageCommand {
    my $self=shift;
    return "sudo port install @_";
}

sub uninstallPackageCommand {
    my $self=shift;
    return "sudo port uninstall @_";
}

sub updatePackageInfoCommand {
    my $self=shift;
    #return "sudo port selfupdate";
    return "sudo port sync";
}
