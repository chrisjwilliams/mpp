# ----------------------------------
# class Pages::AllProjects
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Pages::AllProjects;
use strict;
use Page;
use Redirection;
our @ISA=qw /Page/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub body {
    my $self=shift;
    my $fh = shift;

    my @filters;
    foreach my $project ( $self->{api}->getProjectManager()->listProjects(@filters) )
    {
        print $fh "<a href=\""
                  , $self->projectPage( $project->name(), $project->version() )
                  , "\">", $project->name(), " ", $project->version()
                  , "</a>\n";
    }
    $self->admin($fh);
}

sub admin {
    my $self=shift;
    my $fh=shift;

    # -- instantiate a new project
    $self->formStart($fh, "createProject");
    print $fh "Project name:";
    print $fh $self->{cgi}->textfield( -name =>'name', -size =>20 );
    print $fh "Version:";
    print $fh $self->{cgi}->textfield( -name =>'version',
                                       -value =>'head',
                                       -size =>20 );
    print $fh "Licence:";
    print $fh $self->{cgi}->textfield( -name =>'licence', 
                                       -value =>'BSD',
                                       -size =>10 );
    $self->formEnd($fh, "Create");
}

sub execute {
    my $self=shift;
    my $action=shift;

    if( $action eq "createProject" )
    {
        my $name = $self->{cgi}->param("name");
        my $version = $self->{cgi}->param("version");
        my $licence= $self->{cgi}->param("licence");
        if( ! defined $name || ! defined $version || ! defined $licence ) {
            return "define a name, version and licence for the new project";
        }
        my $project = $self->{api}->getProjectManager()->newProject($name,$version,
                                                                    $licence);
        return Redirection->new( $self->projectPage($name,$version) );
    }
}

sub projectPage {
    my $self=shift;
    my $name=shift;
    my $version=shift;

    return $self->url( { page => "ProjectPage",
            project => $name,
            version => $version } );
}

