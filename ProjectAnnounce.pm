# ----------------------------------
# class ProjectAnnounce
# Description:
# Announce project to html
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package ProjectAnnounce;
use strict;
use INIConfig;
use FileHandle;
use RemoteFileHandle;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{config}=shift;
    die("undefined root"), if ( ! defined $self->{config}{root} );
    $self->{project}=shift;
    $self->{root}=$self->{config}{root}."/".($self->{project}->name());
    mkdir $self->{root} or die "unable to create directory ".($self->{root}).": $!";
    bless $self, $class;
    $self->_restore();
    return $self;
}

sub publish {
    my $self=shift;
    my $level=shift;

    #$self->_generateRepositoryPages();
    my $version=$self->{project}->version();
    if( ! defined $self->{versions}{$level}{$version} ) {
        $self->{versions}{$level}{$version}=$self->_releasePage($level);
        $self->_releaseIndex($level);
    }
    $self->_save();
}

sub unpublish {
    my $self=shift;
    my $level=shift;

    my $version=$self->{project}->version();
    if( defined $self->{versions}{$level}{$version} ) {
        $self->_releasePageRemove($level);
        delete $self->{versions}{$level}{$version};
        $self->_releaseIndex($level);
    }
    $self->_save();
}

sub _releaseIndex {
    my $self=shift;
    my $level=shift;

    my $base=$self->{root}."/".$level;
    my $filename=$base."/release.html";
    my $fh=$self->_file();
    $fh->open(">".$filename) or die "unable to open file $filename : $!";
    $self->_header($fh);
    print $fh "<h1><centre>",$self->{project}->name(),"</centre></h1>";
    print $fh "<h3>Type: $level</h3>";
    print $fh "<ul>";
    foreach my $ver ( sort(keys %{$self->{versions}}) ) {
        my $ref="release_".$ver.".html";
        print $fh "<li><a ref=\"$ref\">$ver</a><br>";
    }
    print $fh "</ul>";
    $self->_footer($fh);
}

sub _releasePageRemove {
    my $self=shift;
    my $level=shift;

    my $fh=$self->_file();

    my $base=$self->{root}."/".$level;
    my $prefix=$base."/release_".($self->{project}->version());
    my $filename=$prefix.".html";
    foreach my $platform ( $self->{project}->platforms() ) {
        my $ref=$prefix."_".($platform->name()).".html";
        unlink $ref or warn "unable to remove file $ref";
    }
    unlink $filename or warn "unable to remove file $filename";
}

sub _releasePage {
    my $self=shift;
    my $level=shift;

    my $fh=$self->_file();

    my $base=$self->{root}."/".$level;
    my $prefix=$base."/release_".($self->{project}->version());
    my $filename=$prefix.".html";
    $fh->open(">".$filename) or die "unable to open file $filename : $!";
    $self->_header($fh);
    print $fh "<h1><centre>",$self->{project}->name(),"</centre></h1>";
    print $fh "<h2><centre>",$self->{project}->version(),"</centre></h2>";
    print $fh "<hr/><p>\n";
    print $fh "<table><tr>";
    print $fh "<th>Platform</th></tr>";
    foreach my $platform ( $self->{project}->platforms() ) {
        my $ref=$prefix."_".($platform->name()).".html";
        $self->_releasePagePlatform($level, $platform, $ref, $base);
        print $fh "<tr><td><a href=\"$ref\">",$platform->name(),"</a></td></tr>";
    }
    print $fh "</tr></table>";
    $self->_footer($fh);
    return $filename;
}

sub _releasePagePlatform {
    my $self=shift;
    my $level=shift;
    my $platform=shift;
    my $filename=shift;
    my $loc=shift;

    my $fh=$self->_file();
    $fh->open(">".$loc."/".$filename) or die "unable to open file $loc/$filename : $!";
    $self->_header($fh);
    print $fh "<h1><centre>",$self->{project}->name(),"</centre></h1>";
    print $fh "<h2><centre>",$self->{project}->version(),"</centre></h2>";
    print $fh "<hr/><p>\n";
    print $fh $self->{propject}->description(), "</p>\n";

    # --- system specific package manager
    print $fh "<h3>", $platform->name(), "</h3>\n";
    my @publishers=$self->{project}->publishers();
    if( $#publishers>=0 ) {
        print $fh "<h2>Install Binary Directly From The Repository</h2>";
        print $fh "Available from the following repositories:<br><table>";
        print $fh "<tr><th>Type</td><th>Name</th><th>Instructions</th></tr>\n";
        foreach my $pub ( $self->{project}->publishers() )
        {
            my $ptype=$pub->type();
            my $pinfo=$self->_repositoryPage($level, $pub);
            my $pname=$pub->name();
            print $fh "<tr><td>$ptype</td><td>$pname</td><td><a href=\"$pinfo\">Howto Use</a></td></tr>\n";
        }
        print $fh "</table>\n";
    }
    else {
        print $fh "No longer published on this platform";
    }

    # --- dependency information - package names on this platform ----
    print $fh "<h2>Dependencies</h2>";
    print $fh "<table><th>Package</th><th>Version</th>\n";
    foreach my $dep ( $self->{project}->dependencies()->platformDependencies("build") ) {
         print $fh "<tr><td>",$dep->{name},"</td><td>",$dep->{version},"</td></tr>";
    }
    $self->_footer($fh);
}

sub _repositoryPage {
    my $self=shift;
    my $pub=shift;
    my $level=shift;

    #return $self->{root}."/repositories/".($pub->name())."_".$level.".html";

}

sub _generateRepositoryPages {
    my $self=shift;
    foreach my $pub ( $self->{project}->publishers() )
    {
#        foreach my $level ( @levels ) {
#           my $filename=$self->_repositoryPage($pub, $level );
#           my $fh=$self->_file();
#           $fh->open(">".$filename) or die ("unable to open $filename : $!");
#           $self->_header($fh);
#           print $fh "<hr><br>\n";
#           print $fh "<h1><centre>", $pub->name(), " ", $level, " Repository</centre></h1>";
#           print $fh "<br><hr>\n";
#           print $fh "<h3>Setting up access to the repository</h3>";
#           print $fh $pub->repositoryInstructions();
#           print $fh "<h3>Installing packages from the repository</h3>";
#           print $fh $pub->packageInstallInstructions();
#           $self->_footer($fh);
#       }
    }
}



sub _header {
    my $self=shift;
    my $fh =shift;
    print $fh "<html><body>\n";
}

sub _footer {
    my $self=shift;
    my $fh =shift;
    print $fh "\n</body></html>\n";
}

sub _init {
    my $self=shift;
    # -- set up directory structure
    #$self->{server}->mkdir($self->{config}{root});
    #$self->{server}->mkdir($self->{config}{root}."/repositories");
}

sub _restore {
    my $self=shift;
    my $fh=$self->_file();
    my $file=$self->{root}."/releases_.info";
    my $ini=INIConfig->new($file);
    
    foreach my $section ( $ini->sections() ) {
        if($section=~/^version::(.*)/ ) {
            my $lev=$1;
            foreach my $v ( $ini->vars($section) ) {
                $self->{versions}{$lev}{$v}=$ini->var($section, $v );
            }
        }
    }
}

sub _save {
    my $self=shift;
    my $fh=$self->_file();
    my $file=$self->{root}."/_releases_.info";
    $fh->open(">".$file) or die "unable to open $file : $!";
    foreach my $level ( keys %{$self->{versions}} ) {
        print $fh "[version::$level]\n";
        foreach my $ver ( keys %${$self->{versions}{$level}} ) {
            print $fh $ver,"=", $self->{versions}{$level}{$ver},"\n";
        }
    }
}

sub _file {
    my $self=shift;
    #my $fh=RemoteFileHandle->new($self->{server});
    my $fh=FileHandle->new();
    return $fh;
}

