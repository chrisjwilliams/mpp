# ----------------------------------
# class MppPublisher::ReleaseInfo
# Description:
#    Encapsulation of package information
#    included in a release
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package MppPublisher::ReleaseInfo;
use INIConfig;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{file}=shift;
    $self->{config}=new INIConfig(((-f $self->{file})?$self->{file}:undef));
    $self->{needsave}=0;
    return $self;
}

sub packages {
    my $self=shift;
    my $ini=$self->{config};
    my @sections=$ini->sections("pack::.*");
    my @packs=();
    for(@sections) {
        $_=~m/pack::(.+?)::(.+)/;
        push @packs, { name=>$1, version=>$2 };
    }
    return @packs;
}

sub hasPackage {
    my $self=shift;
    my $pkg=shift;
    my $version=shift;
    return $self->{config}->definedSection("pack::".$pkg."::".$version);
}

sub packageInfoFile {
    my $self=shift;
    my $name=shift || return;
    my $version=shift || return;

    my $ini=$self->{config};
    return $ini->var("pack::".$name."::".$version,"info");
}

sub addPackage {
    my $self=shift;
    my $name=shift;
    my $version=shift;
    my $info=shift;
    $self->{needsave}=1;
    my $ini=$self->{config};
    #$ini->setVar("packages",$name,$version);
    $ini->setVar("pack::".$name."::".$version, "info", $info);
}

sub remove {
    my $self=shift;
    my $name=shift || return;
    my $version=shift || return;
    $self->{needsave}=1;
    my $ini=$self->{config};
    $ini->clearSection("pack::".$name."::".$version);
}

sub saveToFileHandle {
    my $self=shift;
    my $fh=shift;
    $self->{config}->saveToFileHandle($fh);
}

sub _save {
    my $self=shift;
    my $fh=shift;
    if( $self->{needsave} ) {
        $self->{config}->saveToFile($self->{file});
    }
}
