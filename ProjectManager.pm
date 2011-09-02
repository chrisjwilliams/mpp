# -----------------------------------------------
# ProjectManager
# -----------------------------------------------
# Description: 
# Interface for managing project description files
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

package ProjectManager;
use strict;
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self={};
    bless $self, $class;
    $self->{config}=shift;
    $self->{api}=shift;
    $self->{loc}=shift;

    #$self->{loc}=$self->{config}->var("mpp", "projectDir");


    return $self;
}

sub listProjects {
    my $self=shift;
    my @filters=@_;
    use DirHandle;
    my $dh=DirHandle->new($self->{loc}) or 
        die "unable to access $self->{loc} $!\n";
    my @files=grep !/^\.\.?$/, readdir($dh);
    my @projnms;
    undef $dh;
    foreach my $file ( @files ) {
        next, if( $file eq "CVS");
        if ( -d $self->{loc}."/".$file ) {
            next, if( $#filters >= 0 && (! grep( /^$file.*/, @filters ) ));
            push @projnms, $file;
        }
    }
    my @projects;
    foreach my $p ( @projnms ) {
        # -- read versions
        my $prjloc=$self->{loc}."/".$p;
        my $dh=DirHandle->new($prjloc) or 
            die "unable to access $prjloc $!\n";
        my @files=grep !/^\.\.?$/, readdir($dh);
        foreach my $file ( @files ) {
            next, if( $file eq "CVS");
            my $fn=$prjloc."/".$file;
            if ( (-d $fn) && (! -l $fn)) {
                my $pj=$self->getProject($p, $file);
                push @projects, $pj;
            }
        }
    }
    return @projects;
}

sub getProject {
    my $self=shift;
    my $name=shift;
    my $version=shift;
    my $publication=shift || $self->{api}->defaultPublication();

    require Project;
    require ProjectInfo;
    # -- get Project Objects
    if ( defined $name && defined $version ) {
        my $prjloc=$self->{loc}."/".$name."/".$version;
        if ( -d $prjloc ) {
            if ( -l $prjloc ) {
                use File::Basename;
                # -- get version from the link
                my $pth=readlink $prjloc;
                $version=basename($pth);
            }
            my $file=$prjloc."/config.ini";
            my $config=INIConfig->new($file);
            $config->mergeSection("verbose", $self->{config} );
            my $pinfo=ProjectInfo->new($config, $prjloc, $name, $version);
            my $pj=Project->new($config, $self->{api}, $pinfo, $publication);
            return $pj;
        }
    }
    return;
}

sub saveProjectConfig {
    my $self=shift;
    my $project=shift;

    my $prjloc=$project->location();
    my $file=$prjloc."/config.ini";
    $project->{config}->saveToFile($file);
}

sub newProject {
    my $self=shift;
    my $name=shift;
    my $version=shift;
    my $licence=shift;

    $licence = "BSD", if( ! defined $licence );

    require Project;
    require ProjectInfo;
    my $rv="";
    if ( defined $name && defined $version ) {
        my $prjloc=$self->{loc}."/".$name."/".$version;
        if ( ! -d $prjloc ) {
            File::Path::mkpath($prjloc, 0, 0755) or die "Unable to create dir $prjloc $!\n";
            my $config=INIConfig->new();
            $config->setVar("project","licence", $licence );
            $config->saveToFile( $prjloc."/config.ini" );
            my $pinfo=ProjectInfo->new($config,$prjloc, $name, $version);
            my $pj=Project->new($config, $self->{api}, $pinfo);
            $rv=$pj; # return a project object
        }
    }
    return $rv;
}

# -- private methods -------------------------

