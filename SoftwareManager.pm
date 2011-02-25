# ----------------------------------
# class SoftwareManager
# Description:
#    Manage Descriptions of Packages
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package SoftwareManager;
use SoftwareDependency;
use PackageInfo;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{loc} = shift;
    if( ! -d $self->{loc} ) {
        mkdir $self->{loc};
    }
    $self->{api} = shift;
    bless $self, $class;
    return $self;
}

sub listPackages {
    my $self=shift;
    my @filters=@_;
    use DirHandle;
    my $dh=DirHandle->new($self->{loc}) or 
        die "unable to access $self->{loc} $!\n";
    my @files=grep !/^\.\.?$/, readdir($dh);
    my @packs;
    undef $dh;
    foreach my $file ( @files ) {
        next, if( $file eq "CVS");
        if ( -d $self->{loc}."/".$file ) {
            next, if( $#filters >= 0 && (! grep( /^$file.*/, @filters ) ));
            push @packs, $file;
        }
    }
    return @packs;
}

sub getPackageById {
    my $self = shift;
    my $id = shift || return;
    my ($name, $version) = split("::",$id);
    return $self->getPackage( $name, $version);
}

sub getPackage {
    my $self = shift;
    my $name = shift;
    my $version = shift;

    my @files;
    push @files, $self->{loc}."/".$name."/config.ini";
    if( defined $version ) {
        push @files, $self->{loc}."/".$name."/".$version."/config.ini";
    }
    my $config = INIConfig->new( @files );
    my $dep = new SoftwareDependency($self->{api}, $name,$config);
    $dep->setVersion($version), if( defined $version );
    return $dep;
}
