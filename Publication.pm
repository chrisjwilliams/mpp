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
    $self->{api}=shift;
    $self->{infoserver}=Server->new($config);
    bless $self, $class;
    return $self;
}

sub name {
    my $self=shift;
    return $self->{config}{name};
}

sub addPublishers {
    my $self=shift;
    push @{$self->{publishers}}, @_;
}

sub releaseLevels {
    my $self=shift;
    return @($self->{releases});
}

sub publicReleaseLevels {
    my $self=shift;
    return @($self->{releases});
}

sub platforms {
    my $self=shift;
}

sub publishers {
    my $self=shift;
    return @{$self->{publishers}};
}

sub publish {
    my $self=shift;
    my $release=shift;
    my $project=shift;
    my @platforms=@_ || $project->platforms();

    for(@platforms) {
        $project->_publishPlatform($_);
    }
}

sub createInstallPackages {
    my $self=shift;

    foreach my $publisher ( $self->publishers() ) {
        my $inicfg=INIConfig->new();
        $inicfg->setVar("project","name", $publisher->name());
        $inicfg->setVar("project","version", 0.0);
        $inicfg->setList("install",@repofiles);
        my $info=new ProjectInfo( $inicfg );
        my $project=new Project->($self->{api}, $info);
        $project->build();
        $project->packages($publisher->arch());
    }
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
        foreach $release ( @releases ) {
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
                $pfh->open($pdir."/$platform.html");
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
