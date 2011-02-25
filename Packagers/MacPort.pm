# ----------------------------------
# class Packagers::MacPort
# Description:
#  The MacPort system used on OSX
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Packagers::MacPort;
use strict;
use Packagers::Packager;
use RemoteFileHandle;
use MacPort::PortFile;
use Digest::MD5::File qw( file_md5_hex );
our @ISA=qw /Packagers::Packager/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    $self->{suffix}="pkg";

    $self->{portCmd}="/opt/local/bin/port";

    return $self;
}

sub projectName {
    my $self=shift;
    my $pname=$self->SUPER::projectName();
    (my $projname=$pname)=~s/_/-/g;
    return $projname;
}

sub srcUploadDir {
    my $self=shift;
    return "/opt/local/var/macports/distfiles/".($self->projectName());
}

sub build {
    my $self=shift;
    my $downloadDir=shift;
    my $log=shift;
    my $localFiles=shift;

    my $portCmd=$self->{portCmd};
    if( ! $self->{config}->itemExists("options","no_build") ) {
        print "Building......\n";
        $self->_portfile($localFiles);
        $self->remote($log, "$portCmd -v build");
    }
    # -- install phase

    print "Creating binary package...\n";
    $self->remote($log, "$portCmd -v pkg");

    print "Storing binary package...\n";
    my $file="work/".$self->projectName();
    $self->{platform}->download( $self->{workdir}, $downloadDir, $file );
}

sub _portfile {
    my $self=shift;
    my $localFiles=shift;
    my $dir="macport";

    my $workDir=$self->{workdir};
    my $projname=$self->projectName();
    die "project name not defined", if (! defined $projname );
    my $version=$self->{config}->var("project","version");
    my $builddeps=$self->buildInfo("buildDependencies");
    my $arch=$self->{platform}->arch();

    # -- prepare portfile
    my $portfile=new MacPort::PortFile();
    $portfile->setPlatform( $self->{platform}->platform() );
    $portfile->setVersion($version);
    $portfile->setName($projname);
    $portfile->setDependencies( split( /,\s*/, $builddeps )), if ( defined $builddeps );
    $portfile->setMaintainers('christopher.williams@oerc.ox.ac.uk');
    $portfile->setHomePage($self->{config}->var("project","url"));
    $portfile->setSrcDir($self->{project}->srcDir());
    my $srcPack=$self->{project}->srcPack();

    my $desc=$self->{config}->var("project","description");
    if( ! defined $desc || $desc eq "" ) {
        $desc="Nobody Knows";
    }
    $portfile->setDescription($desc);
    $portfile->setLongDescription($self->{config}->list("description"));
    my $src=$localFiles."/".$srcPack;
    if( -f $src ) {
        my $mdf=file_md5_hex($src);
        $portfile->setCheckSum( "md5" , $mdf );
        $portfile->setBzip(), if( $src=~/\.bz2/ );
    }
    my $cmd=$self->buildInfo("cmd");
    if( defined $cmd ) {
        $portfile->setBuildCmd($cmd);
    }
    my $config=$self->buildInfo("configCmd");
    if( ! defined $config ) {
        $portfile->setConfigure(0);
    }
    else {
        if( $config=~/^\s*\.?[\\\/]?configure\s+(.*)/ ) {
            $portfile->setConfigureArgs(split (/\s+/, $1 ));
        }
        else {
            $portfile->setConfigure($config);
        }
    }

    # -- write portfile
    my $fh=RemoteFileHandle->new($self->{platform});
    my $pfile="Portfile";
    $fh->open(">".$workDir."/".$pfile) or die ( "unable to open file $pfile $!\n" );
    $portfile->write($fh);
    $fh->close();
}

sub _prepareDir {
    my $self=shift;
    $self->{platform}->mkdir( $self->{workdir}, "macport" );
}
