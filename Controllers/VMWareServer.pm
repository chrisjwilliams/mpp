# ----------------------------------
# class Controllers::VMWareServer
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Controllers::VMWareServer;
use strict;
use Controller;
our @ISA=qw /Controller/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    if ( !defined $self->{server} ) {
        $self->{server}=new LocalHost;
    }
    if ( !defined $self->{serverUrl} ) {
        $self->{serverUrl}="https://localhost:8333/sdk";
    }
    @{$self->{cmds}} = ( qw(/usr/bin/vmrun -T server -h),
             $self->{serverUrl}.":".$self->{config}{port}."/sdk",
             "-u", $self->{server}->config("vmware","username"),
             "-p", $self->{server}->config("vmware","passwd") );
    bless $self, $class;
    return $self;
}

sub startPlatform {
    my $self=shift;
    my $platform=shift;
    my $cmds="/bin/vim-cmd ";
    my $id = $self->_getId( $platform );
    return $self->_command("start", $id);
}

sub stopPlatform {
    my $self=shift;
    my $platform=shift;
    my $id = $self->_getId( $platform );
    return $self->_command("stop", $id);
}

sub _command {
    my $self=shift;
    my $cmd=shift;

    return $self->{server}->invoke( join(" ", @{$self->{cmds}}, $cmd, @_( );
    #    if( $! ne "Operation now in progress" ) {
    #       die("failed to execute @{$self->{cmds}} $cmd @_ :\n$! : ".($? >> 8));
    #   }
    #
    #return $report;
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
