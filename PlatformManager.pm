# -----------------------------------------------
# PlatformManager
# -----------------------------------------------
# Description: 
# Factory for Platform Objects
#
#
# -----------------------------------------------
# Copyright Chris Williams 2008
# -----------------------------------------------
# Interface
# ---------
# new()    : new object
#
#

package PlatformManager;
use Platform;
use INIConfig;
use File::SearchPath;
use File::PluginFactory;
use MppClass;
use File::Basename;
use strict;
our @ISA=qw /MppClass/;
1;

# -- initialisation

sub new {
    my $class=shift;
    my $config=shift;
    my $self=$class->SUPER::new($config);
    bless $self, $class;
    $self->{loc}=shift;
    $self->verbose("Platform configuration files at : ".$self->{loc});
    my $data=$self->{loc}."/Data";
    (mkdir $data or print "warning: unable to create $data : $!\n"), if ( ! -d $data );
    $self->{api}=shift;
    $self->{pmc}=shift; # the platform manager collection object
    $self->{path}=$self->{api}->path();
    $self->{platformPath}=File::SearchPath->new();
    #$self->{platformPath}->add( $config->list("platformLocation") );
    $self->{platformPath}->add( $self->{loc} );
    $self->{packageFactory}=$self->{api}->packageFactory($self->{loc});
    $self->{data}=File::SearchPath->new( join( "/Data:", $config->list("platformLocation")) );
    $self->{pi}=File::PluginFactory->new($self->{path});

    return $self;
}

sub packageFactory {
    my $self=shift;
    return $self->{packageFactory};
}

sub localhost {
    my $self=shift;
    return $self->{pmc}->localhost();
}
#
#    my $context=$self->{api}->getDefaultContext();
#    my $contextid = $context->id();
#        
#    if( ! defined $self->{"localhost"}{$contextid} )
#    {
#        $self->verbose("creating localhost object");
#        my $p;
#        eval {
#            # -- maybe its configured
#            $p = $self->getPlatform("localhost", $context);
#        };
#        if ( $@ || ! defined $p ) {
#        $self->verbose("Default config for localhost $@");
            # -- unix only
#            my $arch=`uname -m`;
#            chomp $arch;
#
#            my $config=INIConfig->new();
#            $config->setVar("system","platform","unix");
#            $config->setVar("system","arch",$arch);
#            $p = Platform->new($config, "localhost",
#                   $self->{data}, $self->{api}, $context);
            # set some likely defaults (provide a localhost config to override)
#            $p->setLoginUser( getlogin() );

#        }
#        $self->{"localhost"}{$contextid}=$p;
#    }
#    return $self->{"localhost"}{$contextid};
#}

sub listPlatforms {
    my $self=shift;
    my @platforms;
    for( $self->{platformPath}->allFiles()) {
        push @platforms, basename($_);
    }
    return @platforms;
    #use DirHandle;
    #my $dh=DirHandle->new($self->{loc}) or 
    #    die "unable to access $self->{loc} $!\n";
    #my @files=grep !/^\.\.?$/, readdir($dh);
    #my @platforms;
    #undef $dh;
    #foreach my $file ( @files ) {
    #    if ( -f $self->{loc}."/".$file ) {
    #        push @platforms, $file;
    #    }
    #}
}

sub definesPlatform {
    my $self=shift;
    my $name=shift;

    my ($loc)=$self->{platformPath}->find($name);
    if ( defined $loc && -f $loc ) {
        return 1;
    }
    return 0;
}


sub getPlatform {
    my $self=shift;
    my $name=shift;
    my $context=shift;

    die("context not provided when trying to start platform $name\n"), if( ! defined $context );
    $self->verbose( "getPlatform :".$name );
    $self->verbose( "getPlatform context is ".( $context->id() ) );
    my $contextid = $context->id();

    # -- get Platform Objects
    if ( defined $name ) {
       if( ! defined $self->{platforms}{$name}{$contextid} )
       {
            #my $loc=$self->{loc}."/".$name;
            my ($loc)=$self->{platformPath}->find($name);
            if ( defined $loc && -f $loc ) {
                $self->verbose( "initialising from file :".$loc );
                my $config=INIConfig->new($loc);
                $config->mergeSection("verbose", $self->{config} );
                my $type=$config->var("system","type");
                if( ! defined $type || $type eq "" ) {
                    $type="Platform";
                }
                else {
                    $type="Platforms::".$type;
                }
                $self->{platforms}{$name}{$contextid}=$self->{pi}->newPlugin($type, $config, $name, 
                                                       $self->{data}, $self, $self->{api}, $context );
                $self->verbose("Instantiated platform $name of type $type");
                $self->verbose("Instantiated platform in context ".($contextid)), if ( defined $context );
            }
            else {
                die "platform $name does not exist";
            }
       }
       return $self->{platforms}{$name}{$contextid};
    }
    return undef;
}

#
# returns the object corresponding to a controller
#
sub getController {
    my $self=shift;
    my $type=shift;
    my $platform=shift;
    my $context=shift || return;

    if( ! defined $type || $type eq "" ) {
        return undef;
    }

    $type="Controllers::".$type;
    my $name=$platform->name();
    $self->verbose("constructing controller of type $type on $name , in context :".($context->id()) );
    $self->{controllers}{$name}=$self->{pi}->newPlugin($type, $self->{config}, $context, $platform, $self->{api} );
    $self->verbose("Instantiated controller $name of type $type");
    return $self->{controllers}{$name};
}

# -- private methods -------------------------

