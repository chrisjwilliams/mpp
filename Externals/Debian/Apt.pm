# -----------------------------------------------
# Debian::Apt
# -----------------------------------------------
# Description: 
# Debian::Apt repository management
#
#
# -----------------------------------------------
# Copyright Chris Williams 2008
# -----------------------------------------------
# Interface
# ---------
# new()    : new object
# add( platform_name, release_name, Debian::Package )
#

package Debian::Apt;
use File::Copy;
use File::Basename;
use Digest::MD5::File qw( file_md5_hex );
use FileHandle;
use DirHandle;
use Debian::Package;
use Carp;
use strict;
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self={};
    bless $self, $class;
    $self->{config}=shift;
    $self->{root}=$self->{config}->{root};
    if( ! defined $self->{root} || $self->{root} eq "" ) {
        die( "root not set for apt repository" );
    }
    $self->_construct();
    return $self;
}

sub hostname {
    my $self=shift;
    my $hostname=$self->{config}->{url};
    $hostname="localhost", if( ! defined $hostname );
    return $hostname;
}

sub repositoryRefs {
    my $self=shift;
    my $platform=shift;
    my $release=shift;

    my $url=$self->hostname();
    #my @urls=("deb $url $platform $release", "deb-src $url $platform $release");
    my @urls=("deb $url $platform $release");
    return @urls;
}

sub add {
    my $self=shift;
    my $platform=shift;
    my $release=shift;
    my $package=shift;

    if( ! defined $package ) {
        croak("Package undefined");
    }
    my $packageFile=$package->filename();
    if( -f $packageFile ) {
        my $arch=$package->arch();
        my $rdir="/dists/$platform";
        my $rrelease=$rdir."/".$release;
        my $bdir=$rrelease."/binary-".$arch;
        my $srcdir=$rrelease."/source";
        my $pool_plat="/pool/".$platform;
        my $pool=$pool_plat."/".$release;
        $self->_mkdirs($rdir,$rrelease,$bdir,$srcdir,$pool_plat, $pool);

        # -- copy file into the repository
        # make filename consistent with control info
        #my $dest=basename($packageFile);
        #if( $packageFile !~/_$arch\.deb/ )
        #{
        #    $dest=~s/(.*)\.deb/$1_$arch\.deb/;
        #}
        my $dest=$self->_poolFile($package);
        copy($packageFile, $self->{root}.$pool."/".$dest ) or die("unable to copy file $packageFile $!\n");
        #copy($package->srcFile(), $srcdir );

        # -- create dists platform file
        $self->_platformFile($rdir, $platform);
        $self->_contentsFile($rdir, $arch);
        $self->_packageFile($bdir, $arch, $platform, $release);
        $self->_platformFileBin($arch,$release,$bdir);
        if( $arch eq "all" ) {
            # must rebuild all the architectures as binary-all is ignored by latter apt
            foreach my $ar ( $self->architectures($platform, $release) ) {
                next, if ( $ar eq "all" );
                my $bindir=$rrelease."/binary-".$ar;
                $self->_packageFile($bindir, $ar, $platform, $release);
            }
        }
    }
    else {
        croak("File '".$packageFile."' does not exist");
    }
}

sub remove {
    my $self=shift;
    my $platform=shift;
    my $release=shift;
    my $pkg=shift;

    $pkg=~s/\.deb$//; # chop off any .deb extension from the package name
    my @archs=@_;
    if( $#archs < 0 ) {
        # remove for all architectures
        @archs=$self->architectures($platform, $release);
    }

    my $pool="/pool/".$platform."/".$release;
    my $rdir="/dists/$platform";
    my $rrelease=$rdir."/".$release;
    foreach my $arch ( @archs ) {
        # -- remove the deb files
        my $pkgfile=$self->{root}.$pool."/".$pkg."_".$arch.".deb";
        if( -f $pkgfile ) {
            unlink $pkgfile 
                or die $pkgfile." does not exist\n";
        }
        my $bdir=$rrelease."/binary-".$arch;
        # -- update the info files
        my $pkgs=$self->_packageFile($bdir, $arch, $platform, $release);
        if( $pkgs < 0 )
        {
            # clean up the binary directory
            my $d=$self->{root}.$bdir;
            unlink $d."/Release";
            rmdir $d or die "unable to remove $d: $!";
        }
        #$self->_contentsFile($rdir, $arch);
    }
}

sub platforms {
    my $self=shift;

    my @platforms=();
    my $dir=$self->{root}."/dists/";
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

sub types {
    my $self=shift;
    my $platform=shift;
    my @types=();
    my $dir=$self->{root}."/dists/$platform";
    if( -d $dir )
    {
        my $dh = DirHandle->new($dir) or die "$dir: $!\n";
        while (defined($_ = $dh->read)) {
            next, if( $_=~/\.\.?/ );
            if( -d $dir."/".$_ ) {
                push @types, $_;
            }
        }
    }
    return @types;
}

sub architectures {
    my $self=shift;
    my $platform=shift;

    my %archs;
    foreach my $release ( @_ ) {
        my $dir=$self->{root}."/dists/".$platform."/".$release;
        if( -d $dir )
        {
            my $dh = DirHandle->new($dir) or die "$dir: $!\n";
            while (defined($_ = $dh->read)) { 
                next, if $_!~/^binary-(.+)/;
                if( -d $dir."/".$_ ) {
                    $archs{$1}=1;
                }
            }
        }
    }
    return ( keys %archs );
}

# -- private methods -------------------------

sub _poolFile {
    my $self=shift;
    my $pkg=shift;

    my $packageFile=$pkg->filename();
    my $arch=$pkg->arch();
    my $dest=basename($packageFile);
    if( $packageFile !~/_$arch\.deb/ )
    {
        $dest=~s/(.*)\.deb/$1_$arch\.deb/;
    }
    return $dest;
}

sub _platformFileBin {
    my $self=shift;
    my $arch=shift;
    my $release=shift;
    my $dir=shift;

    my $rfile=$self->{root}.$dir."/Release";
    my $fh = FileHandle->new();
    $fh->open(">".$rfile) or die "unable to create file $rfile";
    print $fh "Archive: mpp_oerc\n",
              "Version: 0.0\n",
              "Origin: MPP\n",
              "Label: MPP\n";

    print $fh "Component: ", $release, "\n";
    print $fh "Architecture: ", $arch, "\n";
    $fh->close();
}

sub _platformFile {
    my $self=shift;
    my $dir=shift;
    my $platform=shift;
    
    $dir=$self->{root}.$dir;
    my $rfile=$dir."/Release";
    my $dh = DirHandle->new($dir) or die("$dir $!");
    my @releases;
    while (defined($_ = $dh->read())) { 
        next, if $_=~/^\.+/;
        if( -d $dir."/".$_ ) {
           push @releases, $_;
        }
    }
    
    my $fh = FileHandle->new();
    $fh->open(">".$rfile) or die "unable to create file $rfile";
    print $fh "Archive: mpp_oerc\n",
              "Version: 0.0\n",
              "Origin: MPP\n",
              "Label: MPP\n";

    print $fh "Components: ", (join (" ", @releases)), "\n";
    print $fh "Architectures: ", 
               join(" ", $self->architectures($platform,@releases) );
    $fh->close();
}

sub _contentsFile {
    my $self=shift;
    my $dir=shift;
    my $arch=shift;
}

sub _packageFile {
    my $self=shift;
    my $dir=shift;
    my $arch=shift;
    my $platform=shift;
    my $release=shift;

    $dir=$self->{root}.$dir;
    my $pfile=$dir."/Packages.gz";
    my $scanDir=$self->{root}."/pool/".$platform."/".$release;
    #my $cmd="dpkg-scanpackages -a ".$arch." ".$scanDir." /dev/null | gzip - > ".$pfile;
    #system($cmd) or die ("unable to create packages file");
    require IO::Compress::Gzip;
    require Debian::Package;
    my $dh=DirHandle->new($scanDir);
    my @files=readdir($dh);
    my @debFiles=grep { /.*\.deb/ } @files;
    my @pkgs=();
    foreach my $deb ( @debFiles ) {
        my $dpack=Debian::Package->new($scanDir."/".$deb);
        my $parch=$dpack->arch();
        if( $parch eq $arch || $parch eq "all" ) {
            push @pkgs, $dpack;
        }
    }
    if( $#pkgs < 0 )
    {
        unlink $pfile or die("unable to remove $pfile : $!\n");
    }
    else {
        my $out=new IO::Compress::Gzip $pfile or die "unable to open file $pfile: $!\n";
        foreach my $dpack ( @pkgs ) {
            foreach my $line ( $dpack->control() ) {
                $out->print($line."\n");
            }
            $out->print("Filename: pool/$platform/$release/".($self->_poolFile($dpack))."\n");
            $out->print("Size: ".(-s $dpack->filename())."\n");
            my $mdf=file_md5_hex($dpack->filename());
            $out->print("MD5sum: ".($mdf)."\n\n");
        }
        $out->print("\n");
        $out->close();
    }
    return $#pkgs;
}

sub _mkdirs {
    my $self=shift;
    foreach my $dir ( @_ )
    {
        my $dir=$self->{root}.$dir;
        if( ! -d $dir )
        {
            mkdir( $dir, 0755) or die "unable to create dir $dir : $!\n";
        }
    }
}

sub _construct {
    my $self=shift;

    # -- deb files live in the pool directory
    #    are seperated in to letter named dirs. lib packages
    #    are treated differently in that the lib and fist letter marks the dir
    #    a dir with the package name, with the debs underneath
    if( ! -d $self->{root} ) {
       mkdir( $self->{root}, 0755) 
                   or die ("unable to make ".$self->{root}." $!\n");
    }
    my $pool="/pool";
    my $dists="/dists";
    $self->_mkdirs( $pool, $dists);
}
