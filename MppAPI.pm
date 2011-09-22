# -----------------------------------------------
# MppAPI
# -----------------------------------------------
# Description: 
# Main API for accessing Core functionality
#
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new( configfile )    : new object
# path()  : return the mpp systems path
# 

package MppAPI;
use INIConfig;
use PackageFactory;
use PublisherFactory;
use Environment;
use File::SearchPath;
use File::Path;
use Context;
use Carp;
use DirHandle;
use strict;
# -- add any mutex variables here. mutex variables must be declared shared before
# starting any threads to actually be shared (memory not shared in perl threads!)
use threads;
use threads::shared;
our $publishers_yum_mutex :shared = "";
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self={};
    $self->{src}=shift;
    $self->{config}=shift;
    bless $self, $class;

    # -- set the global variables
    $self->{globals}=Environment->new();
    if( defined $ENV{HOME} ) {
        $self->{globals}->set("home", "$ENV{HOME}" );
    }

    # -- set working areas
    my $workdir=$self->expandGlobals( $self->{config}->var("mpp","workDir") );
    my $base=$self->expandGlobals( $self->{config}->var("mpp","baseDir") );

    if( (scalar $self->{config}->list("softwareLocation")) < 0 ) {
        die( "[softwareLocation] or baseDir have not been defined" ), if ( ! defined $base );
        $self->{config}->setList($base."/Software");
    }
    if( scalar $self->{config}->list("platformLocation") < 0 ) {
        die( "[platformLocation] has not been defined anywhere" );
    }
    if( scalar $self->{config}->list("projectLocation") < 0 ) {
        die( "[projectLocation] has not been defined anywhere" );
    }
    if( scalar $self->{config}->list("publicationLocation") < 0 ) {
        die( "[publicationLocation] has not been defined anywhere" );
    }
    if( ! defined $workdir ) {
        die( "workDir has not been defined in \"[mpp]\"" );
    }
    mkdir ( $workdir ) || die ("unable to make directory $workdir"), if( ! -d $workdir );
    $self->{workdir} = $workdir;

    #if ( ! -d $self->{platformbase}) { 
    #    File::Path::mkpath($self->{platformbase}, 0, 0755) 
    #        or die "Unable to create dir $self->{platformbase} $!\n";
    #}


    return $self;
}

sub defaultPublication {
    my $self=shift;
    if( ! defined $self->{publication} ) {
        my $default=$self->{config}->var("mpp","defaultPublication");
        if( ! defined $default ) {
            die( "defaultPublication has not been defined in \"[mpp]\"" );
        }
        $self->{publication}=$self->getPublicationManager()->getPublication($default);
    }
    return  $self->{publication};
}

sub setPublication {
    my $self=shift;
    my $pub=shift;
    $self->{publication}=$self->getPublicationManager()->getPublication($pub), if defined ( $pub );
}

sub expandGlobals {
    my $self=shift;
    my $string=shift;
    return $self->{globals}->expandString($string);
}

sub configVar {
    my $self=shift;
    my $section=shift;
    my $var=shift;
    return $self->expandGlobals( $self->{config}->var($section, $var) );
}

sub getConfig {
    my $self=shift;
    return $self->{config};
}

sub externalsDir {
    my $self=shift;
    return $self->{src}."/Externals";
}

sub path {
    my $self=shift;
    if( ! defined $self->{path} ) {
        $self->{path}=new File::SearchPath( $self->{src} );
        $self->{path}->add($self->externalsDir());
    }
    return $self->{path};
}

sub getSoftwareManager {
    require SoftwareManager;
    require SoftwareManagerCollection;
    my $self=shift;
    if ( ! defined $self->{soft} ) {
        $self->{soft}=SoftwareManagerCollection->new($self->{config});
        foreach my $dir ( $self->{config}->list("softwareLocation") ) {
            $self->{soft}->addManager(SoftwareManager->new($self->{softwareloc}, $self ));
        }
    }
    return $self->{soft};
}

sub getProjectManager {
    require ProjectManager;
    require ProjectManagerCollection;
    my $self=shift;
    if ( ! defined $self->{project} ) {
        $self->{project}=ProjectManagerCollection->new($self->{config});
        foreach my $dir ( $self->{config}->list("projectLocation") ) {
            $self->{project}->addManager(ProjectManager->new($self->{config}, $self, $dir) );
        }
        #$self->{project}=ProjectManager->new($self->{config}, $self, $self->{prjloc});
    }
    return $self->{project};
}

sub getPlatformManager {
    require PlatformManager;
    require PlatformManagerCollection;
    my $self=shift;
    if ( ! defined $self->{platm} ) {
        $self->{platm}=PlatformManagerCollection->new($self->{config}, $self );
        foreach my $dir ( $self->{config}->list("platformLocation") ) {
            $self->{platm}->addManager(PlatformManager->new($self->{config}, $dir, $self, $self->{platm} ));
        }
    }
    return $self->{platm};
}

sub getContextualisedPlatforms {
    my $self=shift;
    my $context=shift;

    my @ps=();
    foreach my $platform ( @_ )
    {
        #print "Fetching platform :", $platform, " in context ", $context->id(), "\n";
        push @ps, $self->getPlatformManager()->getPlatform($platform, $context);
    }
    return @ps;
}

sub getPlatforms {
    my $self=shift;
    return $self->getContextualisedPlatforms($self->getDefaultContext(), @_ );
}

sub getPublicationManager {
    my $self=shift;
    if ( ! defined $self->{publicationFac} ) {
        require PublicationManager;
        $self->{publicationFac}=PublicationManager->new( $self );
    }
    return $self->{publicationFac};
}

sub getPublisherFactory {
    my $self=shift;
    if ( ! defined $self->{pubFac} ) {
        $self->{pubFac}=PublisherFactory->new($self->{src}."/Publishers", $self->{config}, $self );
    }
    return $self->{pubFac};
}

#sub packageInfo {
#    my $self=shift;
#    my $platform=shift;
#    return undef, if ( ! defined $platform );
#    my $pfac=$self->packageFactory();
#    return $pfac->getPackage($platform,@_);
#}

sub packageFactory {
    my $self=shift;
    my $loc=shift || die("packageFactory - deprected call: need to specify a PLATFORM location");
    if ( ! defined $self->{packageFac}{$loc} ) {
        $self->{packageFac}{$loc}=PackageFactory->new($self->{config}, $loc, $self);
    }
    return $self->{packageFac}{$loc};
}

sub installRepository {
    my $self=shift;
}

sub getDefaultContext {
    my $self=shift;
    if ( ! defined $self->{context} ) {
        $self->{context}=new Context("default", $self->{workdir});
    }
    return $self->{context};
}

#
# pass down arguments for the packager constructor after type
#
sub createPackager {
    my $self=shift;
    my $type=shift;

    return undef, if ( ! defined $type );
    my $dh=DirHandle->new($self->{src}."/Packagers");
    die("cannot read dir".($self->{src}."/Packagers")), if( ! defined $dh);
    my @files=$dh->read();
    my ($t)=grep( /^$type/i, @files );
    if( ! defined $t || $t eq "" ) {
        croak "unable to find packager of type '$type'";
    }
    $t=~s/\.pm$//;
    #(my $Type=$type)=~s/(\w+)/\u$1/;
    my $pkg="Packagers::".$t;
    eval "require $pkg" or die "Failed to load $pkg : $! $@";
    return $pkg->new(@_);
}

# -- private methods -------------------------

