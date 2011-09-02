# ----------------------------------
# class Manglers::Base
# Description:
#  Base class for all string manglers
# Version Schemes change a given string into a suitably mangled version
#-----------------------------------
# Static Methods:
# getManger(@manglertypes);aget a Mangler composed of the named types
#
# Methods:
# new() :
# mangel(string) : perform the mangling on the given string
# addMangler(@manglers) : add manglers to diasychain the mangled string through
# _mangelString(string) : override this method to do the class specific mangling
#-----------------------------------


package Manglers::Base;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    return $self;
}

# N.B. this is a function not a method
sub createMangler {
    my $first=shift;

    my $mangler=_getMangler($first);
    for(@_) {
        $mangler->addMangler( _getMangler($_) );
    }
    return $mangler;
}

sub mangle {
    my $self=shift;
    my $string=$self->_mangleString(shift);
    for(@{$self->{manglers}}) {
        $string=$_->mangle($string);
    }
    return $string;
}
#
# Base class does no mangling
# override this method to do the work
#
sub _mangleString {
    my $self=shift;
    my $string=shift;
    return $string;
}

sub addMangler {
    my $self=shift;
    push @{$self->{manglers}}, @_;
}

sub _getMangler {
    my $type=shift;
    my $pkg="Manglers::".$type;
    eval "require $pkg" or die "Failed to load $pkg : $! $@";
    return $pkg->new();
}
