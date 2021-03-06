# ----------------------------------
# class Publication
# Description:
#   Specifies a collection of publishers and provides
#   services for managing them as a group
#-----------------------------------
# Methods:
# new() :
# createInstallPackages() : creates a collection of install packages for each repository
# setupRepositories       : setup repositories on a particular platform
#-----------------------------------

package Publication;
use strict;
use MppClass;
our @ISA=qw /MppClass/;
use FileHandle;
use Server;
use RemoteFileHandle;
use File::Copy;
use Manglers::Base;
use PackageVersion;
use PublicationInfo;
use Report;
use Carp;
1;

sub new {
    my $class=shift;
    my $config=shift;
    my $self=$class->SUPER::new($config);
    bless $self, $class;
    $self->{api}=shift;
    $self->fatal("no name specified"), if( ! defined $config->var("publication","name"));
    #$self->{infoserver}=Server->new($config);
    return $self;
}

sub name {
    my $self=shift;
    return $self->{config}->var("publication","name");
}

#
#  return a list of the supported platforms
#
sub getPlatformList {
    my $self=shift;
    return $self->{config}->list("platforms");
}

sub getPlatforms {
    my $self=shift;
    return $self->{api}->getPlatforms($self->getPlatformList());
}

#
# return the name of a substitue platform for a given context
#
sub platformSubstitution {
    my $self=shift;
    my $name=shift;
    my $usecase=shift;

    my @keys=qw(platform);
    if( defined $usecase && $usecase ne "" ) {
        push @keys,$usecase."Platform";
    }
    foreach my $key (@keys) {
        my $pname=$self->{config}->var("platform::$name",$key);
        if( defined $pname ) {
            return $pname;
        }
    }
    return $name;
}

sub releaseLevels {
    my $self=shift;
    return ($self->{config}->list("levels"), "mpp_test");
}

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
                $self->verbose("getPlatformRepositories(".($platform->name()).") : $nm\n");
                push @repos, $candidate;
            }
        }
    }
    return @repos;
}

sub removeReleaseRepositories {
    my $self=shift;
    my $log=shift;
    my $release=shift; # release level
    my $platform=shift;

    my @repos=$self->getPlatformRepositories($platform);
    $self->removeRepositories( $log, $platform, $release, @repos );
}

#
# remove the repositories passed as a list
sub removeRepositories {
    my $self=shift;
    my $log=shift;
    my $platform=shift;
    my $release=shift;
        
    for( @_ ) {
        my $msg="removing repository ".$_->name()." release: $release platform: ".$platform->name();
        $self->verbose($msg);
        print $log $msg."\n",if(defined $log);
        $platform->removePackageRepository($log,$release, $_);
    }
    return @_;
}

sub setupRepositories {
    my $self=shift;
    my $log=shift;
    my $release=shift; # release level
    my $platform=shift;

    my @repos=$self->getPlatformRepositories($platform);
    for( @repos ) {
        my $msg="adding repository ".$_->name()." release: $release platform: ".$platform->name();
        $self->verbose($msg);
        print $log $msg."\n",if(defined $log);
        $platform->addPackageRepository($log,$_,$release);
    }
    return @repos;
}

sub getPackager {
    my $self=shift;
    my $type=shift;
    my $platform=shift;

    my $pf=$self->{api}->createPackager($type,$platform, @_);
    # -- set publication specific options on the packager
    if( defined $platform ) {
        my $schema=$self->platformInfo("versionMangler", $platform);
        if( defined $schema && $schema ne "" ) {
            $self->verbose("setting version mangler to $schema");
            $pf->setVersionMangler( Manglers::Base::createMangler(split(/,/,$schema)) );
        }
    }
    return $pf;
}

sub getRepository {
    my $self=shift;
    my $name=shift;

    my $pf=$self->{api}->getPublisherFactory();
    my $repo=$pf->getPublisher( $name );
    return $repo;
}

sub unpublish {
    my $self=shift;
    my $release=shift;
    my $project=shift;
    my @platforms=@_;

    if( $#platforms < 0 ) { @platforms=$project->getPlatforms() };

    my $msg="project \"".$project->name()."\" \"".$project->version()."\" ";
    my $report=new Report;
    if( ! grep( /$release/ , $self->releaseLevels() ) ) {
        $self->verbose("cannot unpublish $msg : release level $release does not exist");
        $report->addStderr("release level \"".$release."\"  is not defined in this publication");
        $report->setReturnValue(1);
        return $report;
    }
    if( $#platforms == -1 ) {
        my $m="cannot unpublish $msg : no platforms specified";
        $self->verbose($m);
        $report->addStderr($m);
        $report->setReturnValue(1);
        return $report;
    }
    foreach my $platform ( @platforms ) {
        my @repos=$self->getPlatformRepositories($platform);
        my @packs=$project->getPackages($platform);
        if( $#packs >= 0 ) {
            foreach my $repo( @repos ) {
                my @ppacks=@packs;
                #my @ppacks;
                #for(@packs) {
                #    if( grep( $_->type() , $publisher->packageTypes()) ) {
                #        push @ppacks, $_;
                #    }
                #}
                if( $#ppacks>=0) {
                    #$self->verbose("removing @ppacks from :'".($repo->name())."'");
                    $repo->remove( $release, @ppacks );
                }
            }
        }
    }
    return $report;
}

sub publish {
    my $self=shift;
    my $release=shift;
    my $project=shift;
    my @platforms=@_;

    if( $#platforms < 0 ) { @platforms=$project->getPlatforms() };

    my $report=new Report;
    if( ! grep( /$release/ , $self->releaseLevels() ) ) {
        $self->verbose("cannot publish project ".$project->name()." ".$project->version()." : release level $release does not exist");
        $report->addStderr("release level \"".$release."\"  is not defined in this publication");
        $report->setReturnValue(1);
        return $report;
    }
    if( $#platforms == -1 ) {
        my $msg="cannot publish project ".$project->name()." ".$project->version()." : no platforms specified";
        $self->verbose($msg);
        $report->addStderr($msg);
        $report->setReturnValue(1);
        return $report;
    }
    # -- ensure all dependencies are available inside this publication
    foreach my $platform ( @platforms ) {
        my $buildstatus=$project->statusPlatform("build", $platform);
        $self->verbose( $platform->name()." Build status of project ".$project->name()." ".$project->version()." : ".$buildstatus);
        if( $buildstatus ne "completed") {
            $report->addStderr("project ".($project->name())." ".($project->version())." has not been built");
            $report->setReturnValue(1);
            return $report;
        }
        $self->verbose("publishing ".($project->name())." on platform ".($platform->name()) );
        foreach my $package ( $project->dependencies() ) {
            #$self->verbose("checking dependency ".($project->name())." on ".($platform->name()), $package );
            #if( ! $self->isPublished($package, $platform, $release) ) {
            #    my $depProject=$package->getProject($package);
            #    if( $depProject ) {
            #        $report->addReport($self->publish($release, $depProject, $release));
            #    }
            #}
            #else { 
            #    $self->verbose("dependency is already published ".($package)." on ".($platform->name()), $package );
            #}
        }
        # -- now publish the packages
        my @repos=$self->getPlatformRepositories($platform);
        my @packs=$project->getPackages($platform);
        if( $#packs >= 0 ) {
            foreach my $repo ( @repos ) {
                #$report->addReport($project->publishPlatform($platform, $release, @repos ));
                my @ppacks=@packs;
                #for(@packs) {
                #    my $type=$_->type();
                #    $self->verbose("checking if repository ".$repo->name()." supports packages of type $type\n");
                #    if( grep( /$type/i , $repo->packageTypes()) ) {
                #            push @ppacks, $_;
                #    }
                #    else {
                #        $self->verbose("package type $type unsupported");
                #    }
                #}
                if( $#ppacks>=0) {
                    if($self->{verbose}) {
                        my $str="";
                        for(@ppacks) {
                            $str.=$_->name();
                        }
                        $self->verbose("publishing $str to :'".($repo->name())."'");
                    }
                    $repo->add( $release, @ppacks );
                }
            }
        }
        else {
            warn("no packages defined");
            $report->addStderr("no packages defined");
            $report->setReturnValue(1);
        }
    }
    return $report;
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
    #return 1, if( $platform->hasPackage( $package ) );

    # -- check if we have an mpp build available
    my $repo;
    if( $repo=$self->getRepository($platform, $release) ) {
        return $repo->isPublished($package);
    }

    return 0;
}

sub infoConsumers {
    my $self=shift;
    if( ! defined $self->{infos} ) {
        @{$self->{infos}}=(); # TODO
    }
    return @{$self->{infos}};
}

sub setupInstallers {
    my $self=shift;
    my @repos=@_;

    if(! @repos) {
        @repos=$self->repositories();
        return, if( !@repos); # no repositories
    }
    my $pubinfo=PublicationInfo->new();
    foreach my $repo ( @repos ) {
        my $pub={}; # keep track of published projects
        foreach my $release ( $self->releaseLevels() ) {
            foreach my $platform ( $self->getPlatforms() ) {
                # -- generate an installation package for each platform type
                my $project=$self->installationPackageProject($repo, $release, $platform);
                #if( ! defined $pub->{$project} ) {
                    # publish any new projects
                #    $project->publish($release);
                #    $pub->{$project}=1;
                #    $pubinfo->addInstaller($project);
                #}
                # -- create an association between this package and platform in
                #    publication information
                $pubinfo->addPlatform($platform, $project);
            }
        }
    }
    # --- pass the publication info to any information consumers
    foreach my $generator ( $self->infoConsumers() ) {
        $generator->execute($pubinfo);
    }
}

#
# return the latest published version at the specified release level
#
sub latestPublishedVersion {
    my $self=shift;
    my $pkg=shift;
    my $platform=shift;
    my $release=shift;

    my $latest=PackageVersion->new();
    my @repos=$self->getPlatformRepositories($platform);
    for( @repos ) {
       my $version=$_->latestPublishedVersion($pkg);
       if( $version > $latest ) {
           $latest=$version;
       }
    }
    return $latest;
}

#
# generate repository installation packages
#
sub installationPackageProject {
    my $self=shift;
    my $repoName=shift;
    my $release=shift;
    my $platform=shift;

    my $repo=$self->getRepository($repoName);
    if( ! defined $self->{package}{$release}{$repoName}{$platform} ) {
        # -- check if there is a no-arch specific package available for a similar platform
        foreach my $plat ( keys %{$self->{package}{$release}{$repoName}} ) {
             # TODO check for noarch()
             # currently assumes that there is a noarch specific platform available 
             if( $plat->platform() eq $platform->platform() ) {
                 $self->{package}{$release}{$repoName}{$platform}=$self->{package}{$release}{$repoName}{$plat};
                 return $self->{package}{$release}{$repoName}{$platform};
             }
        }

        # -- generate a suitable project to build a package
        my $projectname=$repoName."_".$platform->platform()."_repository";
        #my $version=$self->latestPublishedVersion($pkgname, $platform, $release);
        #if( ! $version->defined() ) { $version=new PackageVersion("0.0.0"); }

        # -- generate a suitable project file
        my $installer=$platform->_getPackageManager();
        my $pm=$self->{api}->getInternalProjectManager();
        my $project=$pm->getProject($projectname, $release, $self);
        if( ! defined $project ) {
            my $config=INIConfig->new();
            $project=$pm->newProject( $projectname, $release, $config, $self );
        }

        # -- setup a buildable Project
        $project->{config}->setVar("project","maintainer",$self->{config}->var("publication","maintainer"));
        my $licence=$self->{config}->var("publication","licence");
        die "please define a licence to use for the repository in [publication]", if( ! defined $licence );
        $project->{config}->setVar("project","licence",$licence);
#print "project=", $project->name(),"\n";
#print "version=", $project->version(),"\n";
        $project->setBuildProcedure($platform, $installer->addRepositoryProcedure($repo,$release));
#        if( ! $project->isBuilt($platform) ) {
            my $report=$project->build($platform);
            die $report, if( $report->failed() );
#        }
        $self->{package}{$release}{$repo}{$platform}=$project;
    }
    return $self->{package}{$release}{$repo}{$platform};
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

sub platformInfo {
    my $self=shift;
    my $name=shift;
    my $platform=shift;
    my $key="platform";
    my @keys=( $key."::".$platform->name(),
               $key."::".$platform->platform() );
    my @vals=$self->{config}->searchVarSections($name, @keys);
    $self->verbose("platformInfo() searching for $name in sections @keys, found @vals");
    return $vals[0]; # only return the first value found
}

sub sectionInfo {
    my $self=shift;
    my $section=shift;
    my $name=shift;
    my $platform=shift;

    my @keys=($section);
    if( defined $platform ) {
        unshift @keys, ($section."::".($platform->name()),
              $section."::".($platform->platform()),
              $section );
    }
    my $val=$self->{config}->searchInfo($name,@keys);
    return $val;
}

