# ----------------------------------
# class Controllers::VMWareESXi
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Controllers::VMWareESXi;
use strict;
use Controller;
our @ISA=qw /Controller/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    if ( !defined $self->{server} ) {
        die("Please specify a platform for the VMWareESXi manager");
    }
    bless $self, $class;
    return $self;
}

sub startPlatform {
    my $self=shift;
    my $platform=shift;
    my $cmds="/bin/vim-cmd ";
    my $id = $self->_getId( $platform );
    $cmds.="vmsvc/power.on $id";
    $self->{server}->invoke($cmds);
}

sub stopPlatform {
    my $self=shift;
    my $platform=shift;
    my $id = $self->_getId( $platform );
    my $cmds="/bin/vim-cmd ";
    $cmds.="vmsvc/power.off $id";
    $self->{server}->invoke($cmds);
}

sub _getId {
    my $self=shift;
    my $platform = shift;
    my $id = $platform->config("vmware", "id");
    if(  ! defined $id || $id eq "" )
    {
        $id = $self->getId($platform);
    }

    return $id;
}
