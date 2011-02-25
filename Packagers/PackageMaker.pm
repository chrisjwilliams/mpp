# ----------------------------------
# class Packagers::PackageMaker
# Description:
#    The MAC PackageMaker .pkg files
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Packagers::PackageMaker;
use strict;
use Packagers::Packager;
our @ISA=qw /Packagers::Packager/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub setup {
    my $self=shift;
    my $downloadDir=shift;
    my $log=shift;

    $self->runCommands( $log, $self->{builder}->setupCommands() );
}

sub build {
    my $self=shift;
    my $downloadDir=shift;
    my $log=shift;

    my $project=$self->{project};
    my $srcDir=$self->{srcDir};

    my $rv=0;
    $self->setup($downloadDir, $log);
    my @cmds=$self->{builder}->buildCommands();
    if( @cmds )
    {
        my $cmd="cd $srcDir && ".(join "&&", @cmds), if ( defined $srcDir && $srcDir ne "" );
        print $log "Building......\n";
        eval { 
            $rv=$self->remote($log,$cmd); 
        };
        if($@)
        {
            $rv=1;
            print $@;
        }
    }

    # -- copy explicit files into the PackageMaker tree
    print $log "Copying Files...\n";
    $self->runCommands( $log, $self->{builder}->installCommands() );

    foreach my $sub ( $project, $project->subpackages() ) {
        my $dir=$self->{builder}->dir($sub->name());
        my $name=$self->_packageFile($sub);
        print $log "Creating package ", $name," in $dir\n";
        #$self->remote($log, "fakeroot dpkg-deb --build $deb ".($name) );
    }

    print $self->{platform}->hostname(), "> Storing packages...\n";
    $self->{platform}->download( $self->{workdir}, $downloadDir, $self->packageFiles() );
    return $rv;
}
