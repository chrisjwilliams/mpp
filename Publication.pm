# ----------------------------------
# class Publication
# Description:
#   Specifies a collection of publishers and provides
#   services for managing them as a group
#-----------------------------------
# Methods:
# new() :
# createInstallPackages() : creates a collection of install packages for each repository
#-----------------------------------

package Publication;
use strict;
use MppClass;
our @ISA=qw /MppClass/;
use FileHandle;
use Server;
use RemoteFileHandle;
use File::Copy;
1;

sub new {
    my $class=shift;
    my $config=shift;
    my $self=$class->SUPER::new($config);
    bless $self, $class;
    $self->{api}=shift;
    $self->fatal("no name specified"), if( ! defined $config->var("publication","name"));
    #$self->{infoserver}=Server->new($config);
    $self->{verbose}=1;
    return $self;
}

sub name {
    my $self=shift;
    return $self->{config}->var("publication","name");
}

#sub releaseLevels {
#    my $self=shift;
#    return @($self->{releases});
#}

#sub publicReleaseLevels {
#    my $self=shift;
#    return @($self->{releases});
#}

sub platforms {
    my $self=shift;
}

sub repositories {
    my $self=shift;
    return $self->{config}->list("repositories");
    #return @{$self->{repos}};
}

sub getPlatformRepositories {
    my $self=shift;
    my $platform=shift;

    my @repos;
    my $pf=$self->{api}->getPublisherFactory();
    my @candidates=$pf->getPlatformPublishers($platform);
    foreach my $candidate ( @candidates ) {
        foreach my $nm ( $self->repositories() ) {
            if ( $candidate->name() eq $nm ) {
                push @repos, $candidate;
            }
        }
    }
    return @repos;
}

sub getRepository {
    my $self=shift;
    my $name=shift;
    my $pf=$self->{api}->getPublisherFactory();
    return $pf->getPublisher( $name );
}

sub publish {
    my $self=shift;
    my $release=shift;
    my $project=shift;
    my @platforms=@_;

    if( $#platforms < 0 ) { @platforms=$project->platforms() };

    # -- ensure all dependencies are available inside this publication
    foreach my $platform ( @platforms ) {
        $self->verbose("publishing ".($project->name())." on platform ".($platform->name()) );
        foreach my $package ( $project->dependencies() ) {
            if( ! $self->isPublished($package, $platform, $release) ) {
                my $depProject=$package->getProject($package);
                if( $depProject ) {
                    $self->publish($release, $depProject, $release);
                }
            }
        }
        # -- now publish the package
        my @repos=$self->getPlatformRepositories($platform);
        $project->publishPlatform($platform, $release, @repos );
    }
}

#
#  returns true if available, 0 if not
#
sub isPublished {
    my $self=shift;
    my $package=shift;
    my $platform=shift;
    my $release=shift;


    # -- check availability on host platform
    return 1, if( $platform->hasPackage( $package ) );

    # -- check if we have an mpp build available
    my $repo;
    if( $repo=$self->getRepository($platform, $release) ) {
        return $repo->isPublished($package);
    }

    return 0;
}

sub createInstallPackages {
    my $self=shift;
    die("createInstallPackages: not yet implemented");

#    foreach my $publisher ( $self->publishers() ) {
#        my $inicfg=INIConfig->new();
#        $inicfg->setVar("project","name", $publisher->name());
#        $inicfg->setVar("project","version", 0.0);
#        $inicfg->setList("install",@repofiles);
#        my $info=new ProjectInfo( $inicfg );
#        my $project=new Project->($self->{api}, $info);
#        $project->build();
#        $project->packages($publisher->arch());
#    }
}

sub installPackage {
    my $self=shift;
    my $platform=shift;
    my $release=shift;

    if( ! defined $self->{package}{$release}{$platform} )
    {
        $self->{package}{$release}{$platform}="something";
    }
    return $self->{package}{$release}{$platform};
}

sub createPublicationInfoHtml {
    my $self=shift;
    my $serv=$self->{infoserver};
    if( defined $serv ) {
        my $name=$self->name();
        $serv->createDir($name);
        # create the releases index page
        my $fh=$serv->fileHandle();
        my @releases=$self->releaseLevels();
        $fh->open(">$name/index.html") or die ("unable to create $name/index.html $!");
        print $fh "Main Release";
        print $fh "<ul>";
        print $fh "<li>",(pop @releases),"</li>";
        print $fh "</ul>";
        print $fh "Other Release Levels";
        foreach my $release ( @releases ) {
            print $fh "<li>$release</li>";
            my $rdir=$name."/".$release;
            $serv->createDir($rdir);
            my $pindex=$serv->fileHandle();
            $pindex->open(">$rdir/index.html") or die ("unable to create $rdir/index.html $!");
            $self->_header($pindex);
            print $pindex "<ul>";
            foreach my $platform( $self->platforms() ) {
                print $pindex "<li>$platform</li>";
                my $pfh=$serv->fileHandle();
                $self->_header($pfh);
                $pfh->open($rdir."/$platform.html");
                $self->_platformHTML($pfh,$platform,$release);
                $pfh->close();
            }
            print $pindex "</ul>";
        }
        $fh->close();
    }
}

sub _header {
    my $self=shift;
    my $fh=shift;
}

sub _platformHTML {
    my $self=shift;
    my $fh=shift;
    my $platform=shift;
    my $release=shift;

    my $package=$self->installPackage($platform,$release);
    my $ploc=$self->url()."/";
    print $fh "<h1>",$platform->name(),"</h1>";
    print $fh "<table><tr><th>", 
               (defined $package)?"<a href=\"$ploc\">$package</a>":"Not available on this platform";
    print $fh "</th></tr></table><br>";
    print $fh "<h2>Installation Instructions</h2>";
    print $fh $platform->installer()->installationHelp();
}
