# ----------------------------------
# class File::PluginFactory
# Description:
#    Base class for object managers that support plugins
#-----------------------------------
# Methods:
# new(File::SearchPath) :
# plugins() : return a list of available plugin names
# newPlugin(name, @args) : return a new object of the specifed type
#-----------------------------------

package File::PluginFactory;
use File::DirIterator;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{path}=shift;
    $self->{ext}="pm"; # perl module extension
    bless $self, $class;
    return $self;
}

sub path {
    my $self=shift;
    return $self->{path};
}

sub plugins {
    my $self=shift;
    my $extension=$self->{ext};
    my @plugins=();
    for($self->{path}->paths()) {
        my $it=File::DirIterator->new($_);
        $it->relativePath();
        $it->setNonRecursive();
        while( my $file=$it->next() ) {
            if( $file=~/^(.+)\.$extension$/ ) {
                push @plugins, $1;
            }
        }
    }
    return @plugins;
}

sub newPlugin {
    my $self=shift;
    my $name=shift;

    my $file=$name.".".$self->{ext};
    $file=~s/::/\//g;
    my @files=$self->{path}->find($file);
    eval { require $file; } or die "Failed to load plugin $name ($file) : $! $@\n";
    return $name->new(@_);
}
