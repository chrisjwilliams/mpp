# -----------------------------------------------
# PublisherFactory
# -----------------------------------------------
# Description: 
# Factory for Generating objects relevant to publication
# 1) Publishers
#    Objects that store and serve package data - usually platform specific
# 2) Publications
#    Collections of Publishers that serve a specific product
# 3) Installers
#    Clients to download and install from a Publisher
#
# -----------------------------------------------
# Copyright Chris Williams 2008
# -----------------------------------------------
# Interface
# ---------
# new()    : new object
#
#

package PublisherFactory;
use Carp;
use Platform;
use INIConfig;
use File::SearchPath;
use File::PluginFactory;
use strict;
use MppClass;
our @ISA=qw(MppClass);
1;

# -- initialisation

sub new {
    my $class=shift;

    my $loc=shift;
    my $config=shift;
    my $self=$class->SUPER::new($config);
    $self->{loc}=File::SearchPath::cleanPath($loc); 
    $self->{config}=$config;
    $self->{api}=shift;
    $self->{pi}=File::PluginFactory->new(File::SearchPath->new($self->{loc}));
    $self->{piInstaller}=File::PluginFactory->new(File::SearchPath->new($self->{loc}."/Installer"));
    return $self;
}

sub typeExists {
    my $self=shift;
    my $type=shift;

    if( ! defined $self->{types} )
    {
        $self->types();
    }
    return (defined $self->{types}{$type});
}

sub types {
    my $self=shift;
    if( ! defined $self->{types} )
    {
        foreach my $file ( $self->{pi}->plugins() ) {
            $self->{types}{lc($file)}=$file;
        }
    }
    return ( keys %{$self->{types}} );
}

sub typeInstallerExists {
    my $self=shift;
    my $type=shift;

    if( ! defined $self->{instTypes} )
    {
        $self->installerTypes();
    }
    return (defined $self->{instTypes}{$type});
}

sub installerTypes {
    my $self=shift;
    if( ! defined $self->{instTypes} )
    {
        foreach my $file ( $self->{piInstaller}->plugins() ) {
            $self->{instTypes}{lc($file)}=$file;
        }
    }
    return ( keys %{$self->{instTypes}} );
}

sub getPublisher {
    my $self=shift;
    my $name=shift;

    if( ! defined $self->{pubs}{$name} ) {
        my $section=$self->{config}->section("repository::$name");
        if( ! defined $section || $section eq "" ) {
            $section=$self->{config}->section("publisher::$name");
    #        print "deprecation warning: [publisher::]. Use [repository::]","\n";
        }
        $section->{verbose}=$self->{config}->var("verbose","Publisher");
        my $type=$section->{"type"};
        $section->{name}=$name, if ( ! defined $section->{name} );
        die "undefined type for publisher '$name'", if (! defined $type || $type eq "" );
        die ("unknown publisher type $type\n"), if( !$self->typeExists( $type ) );
        $self->{pubs}{$name}=$self->{pi}->newPlugin("Publishers::".$self->{types}{$type}, $section);
    }
    return $self->{pubs}{$name};
}

sub publishers {
    my $self=shift;
    my @pubs=();
    foreach my $section ( $self->{config}->sections() ) {
        next, if $section!~/^publisher::(.+)/;
        push @pubs, $1;
    }
    return @pubs;
}

sub publications {
    my $self=shift;
    my @pubs=();
    foreach my $section ( $self->{config}->sections() ) {
        next, if $section!~/^publication::(.+)/;
        push @pubs, $1;
    }
    return @pubs;
}

sub getPublication {
    my $self=shift;
    my $name=shift;

    if( ! defined $self->{publication}{$name} ) {
        my $section=$self->{config}->section("publication::$name");
        $section->{verbose}=$self->{config}->var("verbose","Publication");
        $section->{name}=$name, if ( ! defined $section->{name} );
        require Publication;
        $self->{publication}{$name}=Publication->new($section);
        #$self->{publication}{$name}->addPublishers($self->{congig->list("publication::$name"));
    }
    return $self->{publication}{$name};
}

sub getPackageInstaller {
    my $self=shift;
    my $type=shift;
    my $platform=shift;
    if( ! defined $self->{installers}{$type} ) {
        die ("unknown package installer type $type\n"), if( !$self->typeInstallerExists( $type ) );
        my $pkg="Publishers::Installer::".$self->{instTypes}{$type};
        $self->{installers}{$type}=$self->{piInstaller}->newPlugin($pkg, $platform);
    }
    return $self->{installers}{$type};
}

sub getPublisherType {
    my $self=shift;
    my $type=shift;

    my $name="";
    # -- look through our defined publishers for one of the specified type
    foreach my $pub ( $self->publishers() )
    {
        my $key="publisher::$pub";
        if($self->{config}->var($key, "type") eq $type ) {
           $name=$pub; 
           last, if( defined $self->{config}->var($key,"default") );
        }
    }
    if( $name eq "" )
    {
        return undef;
        #die "no publisher of type '$type' has been defined";
    }
    return $self->getPublisher($name);
}

sub getPlatformPublishers {
    my $self=shift;
    my $platform=shift;

    my @publishers=();
    # get the default type
    #my $type=$platform->packageManagerType();
    my @types=$platform->packageManagerType();
    for(@types) {
        $self->verbose("looking for client type $_");
        die "unable to determine publisher for package manager '".$_."'", if( ! $self->typeInstallerExists( $_ ));
        my $inst=$self->getPackageInstaller($_, $platform);
        my @repTypes=$inst->repositoryTypes();
        for ( @repTypes ) {
            $self->verbose("looking for server type $_");
            if( $self->typeExists( $_ ) ) {
                my $pub=$self->getPublisherType( $_ );
                push @publishers, $pub, if(defined $pub);
            }
            else {
                die("Publisher type '$_' does not exist (available types:".(join( " ", $self->types()))."\n");
            }
        }
    }
    return @publishers;
}
# -- private methods -------------------------

