# ----------------------------------
# class PublicationManager
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package PublicationManager;
use strict;
use File::Basename;
use INIConfig;
use MppClass;
use Publication;
our @ISA=qw /MppClass/;
1;

sub new {
    my $class=shift;
    my $api=shift;
    my $self=$class->SUPER::new($api->getConfig());
    bless $self, $class;
    $self->{api}=$api;
    $self->{pubPath}=File::SearchPath->new();
    $self->{pubPath}->add($self->{config}->list("publicationLocation"));
    $self->verbose("publication configuration files in:",$self->{pubPath}->paths() );
    return $self;
}

sub listPublications {
    my $self=shift;
    my @publications;
    for( $self->{pubPath}->allFiles()) {
        push @publications, basename($_);
    }
    return @publications;
}

sub getPublication {
    my $self=shift;
    my $name=shift;
    if ( defined $name ) {
       if( ! defined $self->{pubs}{$name} ) {
            my ($loc)=$self->{pubPath}->find($name);
            if( defined $loc ) {
                $self->verbose( "initialising $name from file :".$loc );
                my $config=INIConfig->new($loc);
                $config->mergeSection("verbose", $self->{config} );
                $self->{pubs}{$name}=new Publication($config, $self->{api});
            }
            else {
                die "publication \"$name\" does not exist";
            }
       }
       return $self->{pubs}{$name};
    }
    return undef;
}

