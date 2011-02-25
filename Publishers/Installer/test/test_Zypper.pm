# ----------------------------------
# class test_Zypper
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package test_Zypper;
use strict;
use Publishers::Installer::Zypper;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    return $self;
}

sub tests {
    return qw( test_installPackageCommand );
}

sub test_installPackageCommand {
    my $self=shift;
    my $cmd="wibble";
    my $zip=Publishers::Installer::Zypper->new( { cmd=>"$cmd" } );
    my $string=$zip->installPackageCommand("testPkg");
    my $exct="sudo $cmd in testPkg";
    die ( "unexpected string '$string' - expecting $exct"), if ( $string ne $string );

    my $zipDef=Publishers::Installer::Zypper->new();
    $string=$zipDef->installPackageCommand("testPkg");
    my $exctdef="sudo zypper in testPkg";
    die ( "unexpected string '$string' - expecting $exctdef"), if ( $string ne $string );
}
