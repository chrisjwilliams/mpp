# ----------------------------------
# class Publishers::Installer::Apt
# Description:
#  Install packages from an Apt repository
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Publishers::Installer::Apt;
use Publishers::Installer::Base;
our @ISA=qw /Publishers::Installer::Base/;
use strict;
1;

sub new {
    my $class=shift;
    my $platform=shift;
    my $self = $class->SUPER::new($platform);
    $self->{config}=shift;
    return $self;
}

sub repositoryTypes {
    return qw(apt);
}

sub installPackageCommand {
    my $self=shift;
    return "sudo apt-get --force-yes -y -qq install @_";
}

sub uninstallPackageCommand {
    my $self=shift;
    return "sudo apt-get -y -qq remove @_";
}

sub updatePackageInfoCommand {
    my $self=shift;
    return "sudo apt-get -qq update";
}

sub addRepositoryProcedure {
    my $self=shift;
    my $repo=shift;
    my $release=shift; # TODO!!!
    my $proc=new SysProcedure::Procedure;
    my $name=$repo->name()."_".$release;
    my $mppconf="/etc/apt/sources.list.d/$name.list";
    my $rfile=SysProcedure::File->new($self->{platform},$mppconf );
    foreach my $ref ( $repo->repositoryRefs( $self->{platform}->platform(), $release ) )
    {
       $rfile->add($ref,"\n");
    }
    $proc->add($rfile);
    return $proc;
}

#sub addRepository {
#    my $self=shift;
#    my $platform=shift;
#    my $repo=shift;
#    my $release=shift;
#
#    my $name=$repo->name()."_".$release;
#    my $mppconf="/etc/apt/sources.list.d/$name.list";
#    require RemoteFileHandle;
#    my $fh=RemoteFileHandle->new($platform);
#    $fh->open(">$mppconf");
#    foreach my $ref ( $repo->repositoryRefs( $platform->platform(), $release ) )
#    {
#       print $fh $ref,"\n";
#    }
#    $fh->close();
#}

sub removeRepository {
    my $self=shift;
    my $repo=shift;
    my $release=shift;
    my $name=$repo->name()."_".$release;
    my $mppconf="/etc/apt/sources.list.d/$name.list";
    my $platform=$self->{platform};
    $platform->rmFile($mppconf);
}
