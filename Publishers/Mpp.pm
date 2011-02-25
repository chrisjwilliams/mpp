# ----------------------------------
# class Publishers::Mpp
# Description:
#    Mpps own distribution system for
# use when platforms have no specific
# distribution mechanism
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package Publishers::Mpp;
use MppPublisher::ReleaseInfo;
use strict;
use DirHandle;
use Publishers::Base;
our @ISA=qw /Publishers::Base/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    bless $self, $class;
    $self->{pool}=$self->{root}."/pool";
    $self->_makedir($self->{pool});
    $self->{release}=$self->{root}."/release";
    $self->_makedir($self->{release});
    return $self;
}

sub packageTypes {
    return qw(mpp);
}

sub packages {
    my $self=shift;
    my $release=shift;
    my $platform=shift;
    my $rel=$self->_getReleaseMeta($release,$platform);
    return ($rel->packages());
}

#
# return the available releases
#
sub releases { #TODO make usable on remote machine
    my $self=shift;
    my $dh=DirHandle->new($self->{release});
    return(), if ( !defined $dh );
    my @rels=grep( !/^\.\.?/, readdir($dh));
    return @rels;
}

#
# return the available platforms for a given release level
#
sub platforms {
    my $self=shift;
    my $release=shift;
    my $dh=DirHandle->new($self->{release}."/".$release);
    return(), if ( !defined $dh );
    my @rels=grep( !/^\.\.?/, readdir($dh));
    return @rels;
}

#
# the releases that a certain package
# is available in
#
sub _packageReleases {
    my $self=shift;
    my $name=shift;
    my $version=shift;

    my @rels;
    for($self->releases()) {
        foreach my $p ($self->platforms($_)) {
            my $ri=$self->_getReleaseMeta($_,$p);
            push (@rels, $ri),  if( $ri->hasPackage($name,$version)) ;
        }
    }
    return @rels;
}

sub remove {
    my $self=shift;
    my $release=shift;
    my @packages=@_;
    my $platforms={};
    for(@packages) {
        my $platform=$_->platform();
        $platforms->{$platform}=1;
        my $arch=$_->arch();
        my $version=$_->version();
        my $name=$_->name();

        # update release Meta
        my $ri=$self->_getReleaseMeta($release,$platform);
        $ri->remove($name,$version);

        if( ! $self->_packageReleases($name,$version)) {
            # if a package is not in any release then we delete all its files
            my $dst=$self->_poolDir($platform,$arch,$name,$version);
            $self->removeTree($dst);
        }
    }
    for(keys %{$platforms} ) {
        $self->_saveReleaseMeta($release, $_);
    }
}

sub add {
    my $self=shift;
    my $release=shift;
    my @packages=@_;

    my $platforms={};
    for(@packages) {
        my $platform=$_->platform();
        $platforms->{$platform}=1;
        my $arch=$_->arch();
        my $version=$_->version();
        my $name=$_->name();
        # make pool directory
        my $dst=$self->_poolDir($platform,$arch,$name,$version);

        # add package files
        $self->copyFile($_->packageFiles(),$dst);

        # create Package Meta
        my $fh=$self->_fileHandle();
        my $pfile=$dst."/Package.info";
        $fh->open(">".$pfile);
        $_->save($fh);

        # update release Meta
        my $ri=$self->_getReleaseMeta($release,$platform);
        $ri->addPackage( $name,$version, $pfile );
    }
    for(keys %{$platforms} ) {
        $self->_saveReleaseMeta($release, $_);
    }
}

sub _saveReleaseMeta {
    my $self=shift;
    my $release=shift;
    my $platform=shift;
    my $ini=$self->_getReleaseMeta($release,$platform);
    my $file=$self->_infoDir($release,$platform)."/Release.info";
    if( $ini->packages() >= 0 ) {
        my $fh=$self->_fileHandle();
        $fh->open(">".$file) or die ("unable to write to meta file $file : $! $?");
        $ini->saveToFileHandle($fh);
    }
    else {
        # no files in the release then 
        # remove the release/platform dir altogether
        $self->removeFile($file);
        $self->removeFile($self->_infoDir($release,$platform));
        $self->deleteIfEmpty($self->{release}."/".$release);
    }
}

sub _getReleaseMeta {
    my $self=shift;
    my $release=shift;
    my $platform=shift;

    if( ! defined $self->{rm}{$release}{$platform} ) {
        my $file=$self->_infoDir($release,$platform)."/Release.info";
        my $ri=new MppPublisher::ReleaseInfo($file);
        $self->{rm}{$release}{$platform}=$ri;
    }
    return $self->{rm}{$release}{$platform};
}

sub _infoDir {
    my $self=shift;
    my $release=shift;
    my $platform=shift;
    my $d = $self->{release}."/$release";
    $self->_makedir($d);
    $d.="/$platform";
    $self->_makedir($d);
    return $d;
}

sub _poolDir {
    my $self=shift;
    my $platform=shift;
    my $arch=shift;
    my $name=shift;
    my $version=shift;

    my $d = $self->{pool}."/$platform";
    $self->_makedir($d);
    $d.="/$arch";
    $self->_makedir($d);
    if( defined $name ) {
        $d.="/$name";
        $self->_makedir($d);
        $d.="/$version";
        $self->_makedir($d);
    }
    return $d;
}
