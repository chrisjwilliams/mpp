# ----------------------------------
# class Publishers::Installer::Zypper
# Description:
#  The Zypper package Manager (As used by SUSE > 10.2)
#  Able to handle Yum, Yast and plain old directories
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Publishers::Installer::Zypper;
use Publishers::Installer::Base;
our @ISA=qw /Publishers::Installer::Base/;
use strict;
1;

sub new {
    my $class=shift;
    my $platform=shift;
    my $self = $class->SUPER::new($platform);
    $self->{config}=shift;
    if( defined $self->{config}{cmd} ) {
        $self->{cmd}=$self->{config}{cmd};
    }
    else {
        $self->{cmd}="zypper";
    }
    bless $self, $class;
    return $self;
}

sub packageTypes {
    return qw(rpm);
}

sub repositoryTypes {
    my $self=shift;
    return qw(yum yast);
}

sub installPackageCommand {
    my $self=shift;
    return "sudo $self->{cmd} --non-interactive in @_";
}

sub uninstallPackageCommand {
    my $self=shift;
    return "sudo $self->{cmd} --non-interactive rm @_";
}

sub updatePackageInfoCommand {
    my $self=shift;
    my $repository=shift;
    return "sudo $self->{cmd} --non-interactive refresh";
}

sub addRepositoryProcedure {
    my $self=shift;
    my $repo=shift;
    my $release=shift;
    my $proc=new SysProcedure::Procedure;
    my $name=$repo->name()."_".$release;
    my $mppconf="/etc/zypp/repos.d/$name.repo";
    my $rfile=SysProcedure::File->new($self->{platform},$mppconf );
    my $count=0;
    foreach my $ref ( $repo->repositoryRefs( $self->{platform}->platform(), $release ) )
    {
        $count++;
        $rfile->add("[$name"."_$count]\n",
              "name=", $name, "_", $count, "\n",
              "type=", $repo->type(), "\n",
              "baseurl=", $ref ,"\n",
              "gpgcheck=0\n",
              "priority=2\n",
              "autorefresh=1\n\n");
    }
    $proc->add($rfile);
    return $proc;
}

sub removeRepository {
    my $self=shift;
    my $repo=shift;
    my $release=shift;
    my $name=$repo->name()."_".$release;
    my $mppconf="/etc/zypp/repos.d/$name.repo";
    my $platform=$self->{platform};
    $platform->rmFile($mppconf);
}
