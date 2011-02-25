# ----------------------------------
# class PlatformManagerCollection
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package PlatformManagerCollection;
use strict;
use MppClass;
use Carp;
our @ISA=qw /MppClass/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    $self->{config}=shift;
    $self->{api}=shift;
    $self->{localhostPath}=File::SearchPath->new();
    bless $self, $class;

    return $self;
}

sub localhost {
    my $self=shift;

    if( ! defined $self->{"localhost"} )
    {
        my $config=INIConfig->new();
        $self->verbose("creating localhost object");
        foreach my $localhost_file ( $self->{config}->list("localhost") ) {
            my $file = $self->{api}->expandGlobals($localhost_file);
            $self->verbose("reading localhost config from: \"".$file."\"");
            $config->readFile($file);
        }
        my $type=$config->var("system","type");
        if( ! defined $type || $type eq "" ) {
            $type="Platform";
        }
        else {
            $type="Platforms::".$type;
        }
        if( ! defined $config->var("system", "arch") ) {
            $self->verbose("Default arch for localhost $@");
            # -- unix only
            my $arch=`uname -m`;
            chomp $arch;
            $config->setVar("system","arch",$arch);
        }
        if( ! defined $config->var("system", "platform") ) {
            $self->verbose("Default platform for localhost $@");
            $config->setVar("system","platform","unix");
        }
        my $p = $type->new($config, "localhost", $self->{data}, $self, $self->{api}, $self->{api}->getDefaultContext() );
        $p->setLoginUser( getlogin() );
        $self->{"localhost"}=$p;
    }
    return $self->{"localhost"};
}

sub addManager {
    my $self=shift;
    my $manager=shift;
    push @{$self->{managers}}, $manager;
}

sub listPlatforms {
    my $self=shift;
    my @prjs;

    foreach my $manager ( @{$self->{managers}} )
    {
        push @prjs, $manager->listPlatforms(@_);
    }
    return @prjs;
}

sub getPlatform {
    my $self=shift;
    my $name=shift;
    my $context=shift || croak "getPlatform() no context defined";
    my $plat;
    foreach my $manager ( @{$self->{managers}} )
    {
        next, if( ! $manager->definesPlatform($name) );
        $self->verbose("platfrom  $name defined in location: ".$manager->{loc});
        eval {
            $plat = $manager->getPlatform($name,$context);
        };
        if( $@ ) {
            $self->verbose("Problem instantiating $name from location: ".($manager->{loc}." : $@"));
        }
        return $plat, if( defined $plat );
    }
    croak "unable to create platform $name", if( ! defined $plat );
}
