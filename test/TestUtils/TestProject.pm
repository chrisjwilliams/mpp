# ----------------------------------
# class TestUtils::TestProject
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package TestUtils::TestProject;
use Project;
use ProjectInfo;
use Carp;
use strict;
our @ISA=qw /Project/;
1;

sub new {
    my $class=shift;
    my $api=shift;
    my $tmpDir=shift || croak "TestProject: please supply tmpdir";
    my $testConfigDir=shift || croak "TestProject: please supply configuration";
    my $publication=shift || croak "TestProject: please supply a publication";
    my $config=shift;
    my $name=shift || "TestProject";
    if( ! defined $config ) {
        $config=new INIConfig;
        $config->setVar("project","license","GPL");
        $config->setVar("project","name",$name);
    }

    # -- create a copy of the project configuration directory
    my $configSrcDir=$testConfigDir."/TestProjects/$name";
    my $dh=DirHandle->new($configSrcDir) or die "unable to open dir ".$configSrcDir;
    my @files=$dh->read();
    foreach my $file ( @files ) {
        next, if( $file=~/^\.+/);
        next, if( ! -f $configSrcDir."/".$file );
        copy($configSrcDir."/".$file, $tmpDir."/".$file );
    }

    my $info=ProjectInfo->new($config, $tmpDir, $name,"testVersion");
    my $self=$class->SUPER::new($config, $api, $info, $publication);
    bless $self, $class;
    return $self;
}

