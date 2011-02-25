# ----------------------------------
# class MppPublisher::DownloadClient
# Description:
#    Download Packages From an MppPublisher
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package MppPublisher::DownloadClient;
use MppPublisher::ReleaseInfo;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{cache}=shift;
    die( $self->{cache}." does not exist"), if ( !-d $self->{cache} );
    $self->{platform}=shift;
    die( "platform not defined" ), if( ! defined $self->{platform} );
    return $self;
}

sub addRepository {
    my $self=shift;
    my $name=shift || return;
    my $base=shift || return;
    my $release=shift;
    
    $self->{reps}{base}{$name}=$base;
    $self->{reps}{release}{$name}=$release;
}

sub reposOnline {
    my $self=shift;
    my $name=shift;
    my @repos;
    if( defined $name) {
        $self->refresh($name), if(!defined $self->{reps}{releaseinfo}{$name});
        @repos=($name), if(defined $self->{reps}{releaseinfo}{$name});
    }
    else {
        $self->refresh(), if(!defined $self->{reps}{releaseinfo});
        @repos=keys %{$self->{reps}{releaseinfo}};
    }
    return @repos;
}

sub packages {
    my $self=shift;
    my $release=shift;

    my $platform=$self->{platform}->platform();
    my $arch=$self->{platform}->arch();
    $self->refresh(), if( ! defined $self->{pi} );
    my @repos=keys %{$self->{reps}{releaseinfo}};
    for(@repos) {
        $self->{pi}->packages($arch);
    }
}

sub getPackage {
    my $self=shift;
    my $name=shift;
    my $version=shift;

    my @repos=$self->reposOnline(@_);
    my $pinfo;
    for(@repos) {
        if( $self->{reps}{releaseinfo}{$_}->hasPackage($name,$version) ) {
            $pinfo=$self->_getPackageInfo($name,$version);
            last;
        }
    }
    if( ! $pinfo ) {
        die("package $name, version $version not found\n");
    }
    # -- download the files specified by the pinfo
    my @files=$self->_url($pinfo->files());
    return @files;
}

sub refresh {
    my $self=shift;
    my @repos;

    if(@_) {
       @repos=@_;
    }
    else {
        # defualt is to refresh all known repos
        @repos=keys %{$self->{reps}{base}};
    }

    # download the Release Package Lists
    for(@repos)
    {
        my $file=$self->_url($self->{reps}{base}{$_}."/releases/".$self->{reps}{release}{$_}."/Package.Info");
        if( defined $file && -f $file ) {
            $self->{reps}{releaseinfo}{$_} = MppPublisher::ReleaseInfo->new($file);
        }
        else {
            print "unable to update repository: '$_'\n";
        }
    }
}

sub _getPackageInfo {
    my $self=shift;
    my $name=shift;
    my $version=shift;
    my $baseurl=$self->{reps}{base}."/".$self->{reps}{releaseinfo}{$name}->packageLocation($name,$version);
    my $file=$self->_url($baseurl);
    my $pinfo=new MppPublisher::PackageInfo($file);
    return $pinfo;
}

sub _url {
    my $self=shift;
    my $url=shift;;

    my $file;
    if($url=~/^file:\/(.*)/) {
        $file=$1;
    }
    else {
        $file=$self->{platform}->fetchURL($self->{cache}, $_);
    }
    print "file=$file\n";
    return $file;
}
