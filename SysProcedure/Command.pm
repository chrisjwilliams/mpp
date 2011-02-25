# ----------------------------------
# class SysProcedure::Command
# Description:
#   execute a command on a remote machine
#-----------------------------------
# Methods:
# new() :
# add(@cmdlist) : add a series of commands to be executed
#                 Any filenames in the command list should be prefixed
#                 with "${root}" to ease relocation (defaults to /).
#-----------------------------------

package SysProcedure::Command;
use strict;
use Env;
use SysProcedure::ProcedureItem;
our @ISA=qw /SysProcedure::ProcedureItem/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub execute {
    my $self=shift;
    my $log=shift;
    if( ref($log) ne "GLOB" )
    {
        unshift @_, $log;
        $log = undef;
    }
    my $root=shift;

    my $env=Env->new({root=>"$root"});
    for(@{$self->{cmds}}) {
        my $cmd=$env->expandString($_);
        $self->{platform}->invoke($cmd, $log);
    }
}

sub addCommand {
    my $self=shift;
    push @{$self->{cmds}}, @_;
}
