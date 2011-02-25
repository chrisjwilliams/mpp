# ----------------------------------
# class PackageInfo
# Description:
#    Hold information about a package and its environment
# The name and version are the name and version known to mpp
# and do not correleate to actual package names/version on the platform
#-----------------------------------
# Methods:
# new() :
# packageNames(mode) : return a list of required package names required for the specified mode
# expandString(string) : expand a string with the packages own environment
#
# modes
# -----
# These describe the use case for the package e.g. build or runtime
#-----------------------------------

package PackageInfo;
use Environment;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{name}=shift;
    $self->{version}=shift || "";
    $self->{env}=Environment->new();
    $self->{env}->namespace("pack::".$self->{name},"pack::".$self->{name}.'::'.$self->{version});
    bless $self, $class;
    return $self;
}

sub name {
    my $self=shift;
    return $self->{name};
}

sub version {
    my $self=shift;
    return $self->{version};
}

sub compare {
    my $self=shift;
    my $pi=shift;

    return 0, if( $self->{name} != $pi->{name} );
    return 0, if( $self->{version} != $pi->{name} );
    return 0, if( $self->{env}->diff($pi->{env})->size() < 0 );
    return 1;
}

# STATIC method (no object reference)
sub standardNames {
    my $mode=shift;
    my $string="";
    my @ss;
    for(@_){
        my @names=$_->packageNames($mode);
        if(@names) {
            push @ss, @names;
        }
    }
    $string=join(",",sort(@ss));
    return $string;
}

#sub standardName {
#    my $self=shift;
#    my $oper=shift || ">=";
#    my $string=$self->{name};
#    if( defined $self->{version} && $self->{version} ne "unknown" && $self->{version} ne "") {
#        $string.=" ".$oper." ".$self->{version};
#    }
#    return $string;
#}

sub packageNames {
    my $self=shift;
    my $type=shift;
    my $found_=shift || {}; # internal variable to prevent circular deps chaos

    my @rv;
    if( ! defined $found_->{$self->{name}}{$self->{version}}) { 
        $found_->{$self->{name}}{$self->{version}}=1;
        for(@{$self->{deps}}) {
            push @rv, $_->packageNames($type, $found_);
            push @rv, $_->packageNames("all", $found_);
        }
        if( defined $self->{packageNames}{$type} ) {
            push @rv, @{$self->{packageNames}{$type}};
        }
        if( defined $self->{packageNames}{"all"} ) {
            push @rv, @{$self->{packageNames}{"all"}};
        }
    }
    return @rv;
}

sub expandString {
    my $self=shift;
    return $self->{env}->expandString(@_);
}

sub merge {
    my $self=shift;
    $self->{env}->merge(@_);
}

sub setPackageNames {
    my $self=shift;
    $self->setPackageNamesType("all",@_);
}

sub setPackageNamesType {
    my $self=shift;
    my $type=shift;

    @{$self->{packageNames}{$type}}=();
    for( @_ ) {
        if( defined $_ && $_ !~/^\s+$/ ) { 
            push @{$self->{packageNames}{$type}},$_;
        }
    }
}

sub addDependency {
    my $self=shift;
    push @{$self->{deps}},@_;
}
