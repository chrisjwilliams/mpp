# ----------------------------------
# class Publishers::Yum
# Description:
#   Maintainance of a Yum repository
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Publishers::Yum;
use strict;
use Publishers::Base;
use DirHandle;
use File::Copy;
use File::Basename;
use Package::Rpm;
our @ISA=qw /Publishers::Base/;
1;


sub new {
    my $class=shift;
    my $self = $class->SUPER::new(@_);
    bless $self, $class;
    return $self;
}

sub packageTypes {
    return "rpm";
}

sub repositoryRefs {
    my $self=shift;
    my $platform=shift;
    my $release=shift;

    my $url=$self->{config}{url};
    return $url."/$platform/$release";
}

sub add {
    my $self=shift;
    my $release=shift;
    my @packages=@_;

    for(@packages) {
        my $platform=$_->platform();
        # --- analyse our package
        my $dir=$platform."/".$release;
        foreach my $package ( $_->packageFiles() ) {
            if( defined $package && $package ne "" ) {
                my $rpm=Package::Rpm->new($package);
                my $arch=$rpm->arch();
                #my $arch=$rpm->arch();

                # -- ensure the structure exists
                my $archdir=$platform."/".$release."/".$arch;
                $self->createDirs($platform, $dir, $archdir);

                # -- copy in the rpm
                $self->copyFile($package, $archdir );
            }
        }
        # -- generate the meta data
        $self->_createrepo($dir);
    }
}

sub remove {
    my $self=shift;
    my $release=shift;

    my @packages=@_;

    for(@packages) {
        my $platform=$_->platform();
        my $dir=$platform."/".$release;
        my $arch=$_->arch();
        my $archdir=$dir."/".$arch;
        foreach my $pkg ( $_->packageFiles() ) {
            $pkg=~s/\.rpm$//; # chop off any .rpm extension from the package name
            $pkg=basename($pkg);
            my $pkgFile=$archdir."/".$pkg.".rpm";
            $self->removeFile($pkgFile);
            # -- clean up directory if empty
            $self->deleteIfEmpty($archdir);
        }
        my @files=$self->listDir($dir);
        if( $#files == 0 ) {
            # delete the meta data if no packages left
            print "cleaning up dir $dir\n";
            $self->_cleanMeta($dir);
            $self->removeFile($dir);
        }
        else {
            $self->_createrepo($dir);
        }
    }
}

sub platforms {
    my $self=shift;

    my @platforms=();
    my $dir=$self->{root};
    if( -d $dir )
    {
        my $dh = DirHandle->new($dir) or die "$dir: $!\n";
        while (defined($_ = $dh->read)) {
            next, if( $_=~/\.\.?/ );
            if( -d $dir."/".$_ ) {
                push @platforms, $_;
            }
        }
    }
    return @platforms;
}

sub architectures {
    my $self=shift;
    my $platform=shift;

    my %archs;
    foreach my $release ( @_ ) {
        my $dir=$self->{root}."/".$platform."/".$release;
        my @dirs=$self->listDir($dir);
        foreach my $d ( @dirs ) {
            $d=~s/^$dir\///;
            next, if( $d=~/^\.+/ );
            next, if( $d=~/^repodata/ );
            $archs{$d}=$d;
        }
    }
    return ( keys %archs );
}

sub _createrepo {
    my $self=shift;
    my $dir=shift;

    $dir=$self->{root}."/".$dir;
    my $cmd="createrepo -q -o $dir";
    if( -d $dir."/repodata" ) {
        $cmd.=" --update";
    }
    lock($MppAPI::publishers_yum_mutex);
    system( "$cmd $dir" ) == 0 or die "unable to modify yum repository '".($self->name())."' $cmd $dir : $!";
}

sub _cleanMeta {
    my $self=shift;
    my $dir=shift;

    # -- removeFile the metadata
    my $repodir=$dir."/repodata";
    $self->removeFile($repodir."/repomd.xml" );
    $self->removeFile($repodir."/filelists.xml.gz" );
    $self->removeFile($repodir."/other.xml.gz" );
    $self->removeFile($repodir."/primary.xml.gz" );
    $self->removeFile($repodir);
}


sub _repositoryRef {
    my $self=shift;
    my $release=shift;
    return $self->{config}{url}."/".$release
}

#
#  Unable to get this to work due to broken RPM::Header :(
#
sub _createHeaders {
    my $self=shift;
    my $dir=shift;

    require IO::Compress::Gzip;
    my $dh=DirHandle->new($dir);
    my @files=readdir($dh);
    my @rpmFiles=grep { /.*\.rpm/ } @files;
    # --- Initialalise the three required files
    my $pfile=$dir."/primary.xml.gz";
    my $file=$dir."/filelists.xml.gz";
    my $otherfile=$dir."/other.xml.gz";
    my $metaout=new IO::Compress::Gzip $pfile or die "unable to open file $pfile: $!\n";
    print $metaout '<?xml version="1.0" encoding="UTF-8"?>',"\n";
    print $metaout "'<metadata xmlns=\"http://linux.duke.edu/metadata/common\" xmlns:rpm=\"http://linux.duke.edu/metadata/rpm\" packages=\"".($#rpmFiles).">\n";
    my $fileout=new IO::Compress::Gzip $file or die "unable to open file $file: $!\n";
    print $fileout '<?xml version="1.0" encoding="UTF-8"?>',"\n";
    print $fileout "<filelists xmlns=\"http://linux.duke.edu/metadata/filelists\" packages=\"",$#rpmFiles,"\">\n";
    my $oout=new IO::Compress::Gzip $otherfile or die "unable to open file $otherfile: $!\n";
    print $oout '<?xml version="1.0" encoding="UTF-8"?>',"\n";
    print $oout "<otherdata xmlns=\"http://linux.duke.edu/metadata/other\" packages=\"",$#rpmFiles,"\">\n";

    foreach my $rpm ( @rpmFiles ) {
        my $pkg=Package::Rpm->new($rpm);
        my $id=$pkg->id();
        my $name=$pkg->name();
        my $arch=$pkg->arch();
        my $version=$pkg->version();
        my $epoch=$pkg->epoch();
        my $rel=$pkg->release();
        my $pkgStr="<package pkgid=\"".$id."\" name=\"".$name."\" arch=\"".$arch."\">";
        print $fileout $pkgStr;
        print $oout $pkgStr;
        print $fileout "<version epoch=\"", $epoch, "\" ver=\"",$version,"\" rel=\"",$rel,"\"/>";
        print $oout "<version epoch=\"", $epoch, "\" ver=\"",$version,"\" rel=\"",$rel,"\"/>";
        print $metaout "<package type=\"rpm\">";
        print $metaout "<version epoch=\"", $epoch, "\" ver=\"",$version,"\" rel=\"",$rel,"\"/>";
        print $metaout "<name>$name</name><arch>$arch</arch>";
        print $metaout "<summary>",$pkg->summary(),"</summary>";
        print $metaout "<description>",$pkg->description(),"</description>";
        print $metaout "<url>",$pkg->url(),"</url>";
        print $metaout "<location href=\"",$rpm,"\" />";
        foreach my $file ( $pkg->files() ) {
            print $fileout "<file>",$file,"</file>";
        }
        foreach my $file ( $pkg->dirs() ) {
            print $fileout "<file type=\"dir\">",$file,"</file>";
        }
        foreach my $change ( $pkg->changeLogs() ) {
            print $oout "<changelog author=\"", $change->author(), "\" date=\"", $change->date(), "\" >";
            print $oout $change->info();
            print $oout "</changelog>";
        }
        print $fileout "</package>\n";
        print $oout "</package>\n";
        print $metaout "</package>\n";
    }

    # --- close up the files
    print $metaout "</metadata>\n";
    print $fileout "</filelists>\n";
    print $oout "</otherdata>\n";
    $metaout->close();
    $fileout->close();
    $oout->close();

    # -- generate the repomd file
    my $rfile=$dir."/repomd.xml.gz";
    my $rout=new IO::Compress::Gzip $rfile or die "unable to open file $rfile: $!\n";
    print $rout '<?xml version="1.0" encoding="UTF-8"?>',"\n";
    print $rout '<repomd xmlns="http://linux.duke.edu/metadata/repo">',"\n";
    foreach my $doc ( qw(filelists other primary) ) {
        my $file=$doc.".xml.gz";
        print $rout "<data type=\"$doc\">\n";
        print $rout " <location href=\"repodata/",$file,"\"/>\n";
        print $rout " <checksum type=\"sha\">", $self->_checksum($file), "</checksum>\n";
        print $rout "</data>\n";
    }
    print $rout "</repomd>\n";
    $rout->close();
}

sub _checksum {
    my $self=shift;
    my $file=shift;
    require Digest::SHA::PurePerl;
    my $sha = Digest::SHA::PurePerl->new();
    $sha->addfile( $file );
    return $sha->hexdigest();
}
