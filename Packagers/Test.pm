# ----------------------------------
# class Packagers::Test
# Description:
# A class that simply records the names of the files it is asked to
# package
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Packagers::Test;
use strict;
use Packagers::Packager;
use INIConfig;
our @ISA=qw /Packagers::Packager/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub build {
    my $self=shift;
    my $downloadDir=shift;
    my $log=shift;

    my $rv=0;
    $self->{buildConfig}=INIConfig->new();
    my $cmd=$self->buildInfo("cmd");
    my $srcDir=$self->{srcDir};
    if( ! $self->{config}->itemExists("options","no_build") ) {
       if( defined $cmd )
       {
           print $log $self->projectName()." running command : $cmd\n";
           $cmd="cd $srcDir && ".$cmd, if ( defined $srcDir && $srcDir ne "" );
           $self->{buildConfig}->setVar("process","cmd",$cmd);
           eval { 
               $rv=$self->remote($log,$cmd); 
           };
           if($@)
           {
               $rv=1;
               print $@;
           }
       }
       print $log "Copying Files...\n";
       # -- give the section iterator a workout ....
       $self->contentIterator( "install", \&_installBuild );
       $self->contentIterator( "install_link", \&_installBuild );
   }
   my $filename=$downloadDir."/".$self->projectName()."_build.testpkg";
   print $log "saving pkg info to file $filename\n";
   $self->{buildConfig}->save($filename);
   return $rv;
}

sub _installBuild {
    my $self=shift;
    my $section=shift;
    my $type=shift;
    foreach my $file ( $self->{config}->list( $section ) ) {
        $self->{buildConfig}->setList($section, $file); 
    }
}
