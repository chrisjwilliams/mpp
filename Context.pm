# ----------------------------------
# class Context
# Description:
#   Class to maiantain data relating to different contexts
#   Primarily based around file stores at the moment, but
#   provides an interface to get context specific configurations
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Context;
use File::Basename;
use File::Path;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{id}=shift;
    $self->{workdir}=shift;
    bless $self, $class;
    return $self;
}

sub setWorkDir {
    my $self=shift;
    $self->{workdir}=shift;
}


sub id {
    my $self=shift;
    return $self->{id};
}

#
# return an INIConfig object for the named dataset
# defined in this context. If the corresponding file does
# not exist it will be created (including an dir structure)
#
sub getConfigINI {
    my $self=shift;
    my $name=shift;

    #my ($f,$dir) = fileparse($name);
    #$dir=$self->{workdir}."/".$dir; 
    #mkdir( $dir ) or die("unable to create dir $dir"), if( ! -d $dir );

    #$f=~s/::/_/g;
    #my $file=$dir.$f.".ini";
    my $file = $self->INI_File($name);
    print "Context Data Stored in $file\n";
    my $ini=INIConfig->new($file);
    $ini->setDefaultFile($file);
    return $ini;
}

sub saveINI {
    my $self=shift;
    my $name=shift;
    my $config = shift;
    my $file = $self->INI_File($name);
    $config->saveToFile($file);
}

sub filename {
    my $self=shift;
    my $name = join( "/", @_);
    my ($f,$dir) = fileparse($name);
    $dir=$self->{workdir}."/".$dir; 
    mkpath( $dir ) or die("Context: unable to create dir $dir"), if( ! -d $dir );
    $f=~s/::/_/g;
    my $file=$dir.$f;
    return $file;
}

sub INI_File {
    my $self=shift;
    my $name=shift;

    my ($f,$dir) = fileparse($name);
    $dir=$self->{workdir}."/".$dir; 
    mkpath( $dir ) or die("Context: unable to create dir $dir"), if( ! -d $dir );

    $f=~s/::/_/g;
    my $file=$dir.$f.".ini";
    return $file;
}
