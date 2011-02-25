# ----------------------------------
# class Publishers::Installer::Yum
# Description:
#  Install packages prom an Yum repository
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Publishers::Installer::Yum;
use Publishers::Installer::Base;
our @ISA=qw /Publishers::Installer::Base/;
use strict;
1;

sub new {
    my $class=shift;
    my $platform=shift;
    my $self = $class->SUPER::new($platform);
    $self->{config}=shift;
    $self->{yum}=$self->{config}{cmd} || "yum";
    return $self;
}

sub packageTypes {
    return qw(rpm);
}

sub repositoryTypes {
    return qw(yum);
}

sub installPackageCommand {
    my $self=shift;
    return "sudo ".($self->{yum})." -y install @_";
}

sub uninstallPackageCommand {
    my $self=shift;
    return "sudo ".($self->{yum})." -y remove @_";
}

sub updatePackageInfoCommand {
    my $self=shift;
    return "sudo ".($self->{yum})." -y clean metadata";
}

sub addRepositoryProcedure {
    my $self=shift;
    my $repo=shift;
    my $release=shift;
    my $proc=new SysProcedure::Procedure;
    my $name=$repo->name()."_".$release;
    my $mppconf="/etc/yum.repos.d/$name.repo";
    my $rfile=SysProcedure::File->new($self->{platform},$mppconf );
    my $count=0;
    foreach my $ref ( $repo->repositoryRefs( $self->{platform}->platform(), $release ) )
    {
        $count++;
        $rfile->add("[$name"."_$count]\n",
              "name=", $name, "_", $count, "\n",
              "baseurl=", $ref ,"\n",
              "gpgcheck=0\n",
              "failovermethod=roundrobin\n\n");
    }
    $proc->add($rfile);
    return $proc;
}

sub removeRepository {
    my $self=shift;
    my $repository=shift;
    my $release=shift;
    my $name=$repository->name()."_".$release;
    my $mppconf="/etc/yum/repos.d/$name.repo";
    my $platform=$self->{platform};
    $platform->rmFile($mppconf);
}
