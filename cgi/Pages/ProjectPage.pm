# ----------------------------------
# class ProjectPage
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Pages::ProjectPage;
use strict;
use CGI::Widget::Tabs;
use RoleMaster::Widgets::GroupManager;
use RoleMaster::Role;
use Page;
our @ISA=qw /Page/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    my $name = $self->{cgi}->param("project");
    my $version = $self->{cgi}->param("version");
    $self->{project} = $self->{api}->getProjectManager()->
                       getProject($name,$version),
                       if( defined $name && defined $version );
    bless $self, $class;
    return $self;
}

sub title {
    my $self=shift;
    my $fh = shift;

    if( ! defined  $self->{project} )
    {
        print $fh "Unknown project";
        return;
    }
    return "Project ".($self->{project}->name())." ".($self->{project}->version());
}

sub groupName {
    my $self=shift;
    return $self->{project}->name();
}

sub execute {
    my $self=shift;
    my $action=shift;

    return, if( !defined $action || $action eq "" );
    $self->{cgi}->delete("action");
    return $self->updatePlatforms(), if( $action eq "platforms" );
    return $self->updateSoftware(), if( $action eq "software" );
    return $self->launchBuild(), if( $action eq "build" );
    return $self->updateUsers(), if( $action eq "users" );
}

sub body {
    my $self=shift;
    my $fh = shift;

    if( ! defined  $self->{project} )
    {
        print $fh "Unknown project requested";
        return;
    }

    print $fh "<h2>Project: ",$self->{project}->name(),"</h2>";
    print $fh "<h3>Version: ",$self->{project}->version(),"</h3>";
    print $fh "<hr><br>";

    # -- project adminstrators display
    my $p = $self->{project};
    my $tab = CGI::Widget::Tabs->new;
    $tab->cgi_object($self->{cgi});
    $tab->headings( qw/Build Platforms Software Users Publish/ );
    $tab->wrap(5);
    $tab->default("Build");
    print $fh $tab->render();
    print $fh "<br>\n";

    if( $tab->active() eq "Platforms" ) {
        $self->platforms($fh);
    }
    elsif( $tab->active() eq "Users" ) {
        $self->users($fh);
    }
    elsif( $tab->active() eq "Software" ) {
        $self->software($fh);
    }
    elsif( $tab->active() eq "Build" ) {
        $self->build($fh);
    }
    elsif( $tab->active() eq "Publish" ) {
        $self->publish($fh);
    }
}

sub platforms {
    my $self=shift;
    my $fh = shift;

    $self->formStart($fh,"platforms");
    $self->hiddenInputs($fh);
    print $fh "<table border=\1\" width=\"100%\"><tr><th>";
    # - platforms available selection
    print $fh "Available Platforms</h2></th><th>";
    print $fh "Project Platforms</th></td></tr><tr><td>";
    print $fh "<select class=\"full\" name=\"platforms\" multiple size=\"20\" >";
    
    foreach my $option ( $self->{api}->getPlatformManager()->listPlatforms() ) {
        if( ! $self->{project}->hasPlatform($option) ) {
            print $fh "<option value=\"", $option, "\">", $option;
        }
    }
    print $fh "</select></td><td>";

    # - platforms selected list
    print $fh "<select class=\"full\" name=\"platformsSelected\" multiple size=\"20\">";
    foreach my $option ( $self->{project}->platforms() ) {
        print $fh "<option value=\"", $option->name(), "\">", $option->name();
    }
    print $fh "</select></td></tr>";
    print $fh "<tr><td>Select to add to Project</td><td>Select to remove from Project</td></tr>";
    print $fh "</td></tr></table>";
    $self->formEnd($fh,"Update");
}

sub updatePlatforms {
    my $self=shift;
    my $changes=0;
    foreach my $platform ( $self->{cgi}->param("platforms") ) {
        ++$changes;
        $self->{project}->addPlatforms($platform);
    }
    foreach my $platform ( $self->{cgi}->param("platformsSelected") ) {
        ++$changes;
        $self->{project}->removePlatforms($platform);
    }
    $self->{api}->getProjectManager()->saveProjectConfig( $self->{project} )
                , if( $changes > 0 );
}

sub updateUsers {
    my $self=shift;

    my $userWidget = $self->_getGroupWidget();
    $userWidget->setCommand("users");
    return $userWidget->execute();
}

sub _getGroupWidget {
    my $self=shift;
    my $gp = $self->{group};
    my $userWidget = RoleMaster::Widgets::GroupManager->new($self->{cgi}, $gp);
    $userWidget->setCommand("users");
    return $userWidget;
}

sub software {
    my $self=shift;
    my $fh = shift;

    # -- dependency mode selector
    my $tab = CGI::Widget::Tabs->new;
    $tab->cgi_object($self->{cgi});
    $tab->cgi_param("dependType");
    $tab->headings( qw/all build test/ );
    $tab->wrap(5);
    $tab->default("all");

    print $fh $tab->render();
    print $fh "<br>\n";

    # -- project dependencies management dialogue
    $self->formStart($fh,"software");
    $self->hiddenInputs($fh);
    print $fh "<h3>Dependencies<h3>";
    print $fh "<table width=\"100%\">";
    print $fh "<tr><th>Name</th><th>Version</th></tr>\n";

    # -- add project dependencies dialogue
    my $type=$self->{cgi}->param("dependType");
    foreach my $pack ( $self->{project}->dependencies( $type ) )
    {
        print $fh "<tr><td>",$pack->name(),"</td><td>", 
                  $pack->version(), "</td><td>",
                  "<input type=\"checkbox\" name=\"softwareRemove\"",
                  "value=\"", $pack->id(), "\" \></td></tr>";
    }
    print $fh "</table>\n";
    $self->formEnd($fh,"Remove Selected");
    print $fh "<br><hr><br>";

    # -- add available packages dialogue
    print $fh "<h3>Available Packages<h3>";
    $self->formStart($fh,"software");
    $self->hiddenInputs($fh);

    print $fh "<select name=\"software\" multiple size=\"10\">";
    my @packages = $self->{api}->getSoftwareManager()->listPackages();
    foreach my $pack ( @packages )
    {
        print $fh "<option value=\"", $pack, "\">", $pack;
    }
    print $fh "</select><br>";
    $self->formEnd($fh,"Add Selected Dependencies");

}

sub updateSoftware {
    my $self=shift;
    my $changes=0;
    my $swmgr = $self->{api}->getSoftwareManager();
    my $type = $self->{cgi}->param("dependType");
    $type = "all", if( ! defined $type );
    my $msg="";
    foreach my $software ( $self->{cgi}->param("software") ) {
        my $sw = $swmgr->getPackage($software);
        if ( defined $sw ) {
            ++$changes;
            $self->{project}->addDependencies($type,$sw);
        }
    }
    foreach my $software ( $self->{cgi}->param("softwareRemove") ) {
        my $sw = $swmgr->getPackageById($software);
        if ( defined $sw ) {
        #$msg.="removing from $type ".($sw->name())." version=\"".($sw->version())."\"";
            ++$changes;
            $self->{project}->removeDependencies($type,$sw);
        }
    }
    $self->{api}->getProjectManager()->saveProjectConfig( $self->{project} )
                , if( $changes > 0 );
    return $msg;
}

sub roles {
    my $self=shift;
    my $buildRole = new RoleMaster::Role("build");
    my $publishRole = new RoleMaster::Role("publish");
    my $adminRole = new RoleMaster::Role("admin");
    $adminRole->setSubserviantRoles($buildRole, $publishRole);
    return ($buildRole,$publishRole,$adminRole);
}

sub users {
    my $self=shift;
    my $fh = shift;

    # -- available users dialogue
    my $userWidget = $self->_getGroupWidget();
    $userWidget->render($fh);

}

sub build {
    my $self=shift;
    my $fh = shift;

    if( $self->{project}->platforms() <= 0 ) {
        print $fh "No platforms defined for this project";
        return;
    }

    my @managers=$self->{project}->executionSteps();
    $self->formStart($fh,"build");
    $self->hiddenInputs($fh);
    print $fh "<table border=\"1\" width=\"100%\">";
    print $fh "<tr><th>Platform</th>";
    foreach my $manager ( @managers ) {
        print $fh "<th>", $manager->name(), "</th>";
    }
    print $fh "<th>Select</th></tr>";
    foreach my $platform ( $self->{project}->platforms() )
    {
        print $fh "<tr>";
        print $fh "<td>", $platform->name(),"</td>";
        # --- print out status information
        foreach my $manager ( @managers ) {
            my $status = $manager->status($platform);
            print $fh "<td>";
            if( ! defined $status ) {
                print $fh "-";
            }
            else {
                print $fh ($status)?"FAIL":"OK";
            }
            print $fh "</td>";
        }
        # --- platform selection checkboxes
        print $fh "<td><input type=\"checkbox\" name=\"build\" value=\"", 
                  $platform->name(),"\" checked=\"true\"/>" ,"</td>";
        print $fh "</tr>\n";
    }
    print $fh "</table>";
    $self->formEnd($fh,"Build Selected");
}

sub launchBuild {
    my $self=shift;
    my @toBuild = $self->{cgi}->param("build");
    my @platforms = $self->{api}->getPlatforms(@toBuild);

    # launch the build in a separate process
    #  using the double fork paradim
    # to avoid zombies
    my $pid = fork;
    unless( $pid )
    {
        # child process
        unless( fork )
        {
            # - grandchild process does the work
            $self->{project}->build(@platforms);
        }
        exit(0);
    }
    # parent process waits for first child
    # which should exit as soon as it has spawned 
    # the grandchild process
    waitpid($pid,0);
}

sub url {
    my $self=shift;
    my $hash=shift;
    $hash={}, if( ! defined $hash );
    $hash->{project}=$self->{project}->name(); 
    $hash->{version}=$self->{project}->version();
    my $url = $self->SUPER::url($hash);
   
}

sub hiddenInputs {
    my $self=shift;
    my $fh = shift;
    
    print $fh "<input type=\"hidden\" name=\"project\" value=\"", 
              $self->{project}->name(),"\" \>";
    print $fh "<input type=\"hidden\" name=\"version\" value=\"", 
              $self->{project}->version(),"\" \>";
    print $fh "<input type=\"hidden\" name=\"tab\" value=\"", 
              $self->{cgi}->param("tab"),"\" \>";
    if( defined $self->{cgi}->param("dependType") ) {
        print $fh "<input type=\"hidden\" name=\"dependType\" value=\"", 
              $self->{cgi}->param("dependType"),"\" \>";
    }
}

sub publish {
    my $self=shift;
    my $fh = shift;

    print $fh "Not yet implemented";
}
