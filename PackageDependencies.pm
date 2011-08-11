# ---------------------------------------
# class PackageDependencies
# Description:
#  Access Package Dependency information
#----------------------------------------
# Methods:
# new() :
# dependencies() : return a list of dependencies
# platformDependencies(platform) : return a list of packagenames for the dependencies
#----------------------------------------

package PackageDependencies;
use SoftwareDependency;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{config}=shift;
    @{$self->{types}}=qw(runtime build optional);
    bless $self, $class;
    return $self;
}

sub dependencies {
    my $self=shift;
    my $type=shift;

    my $key=$self->_getSection($type);
    return $self->_deparray($self->_dependencies($key, {}));
}

sub platformDependencies {
    my $self=shift;
    my $platform=shift;
    my $type=shift;

    return $self->platformPackages($platform,$type);
#    my @rv;
#    foreach my $pkg ( $self->platformPackages($platform,$type) ) {
#        push @rv,$pkg->packageNames($type);
#    }
#    return @rv;
}

#
#  returns a hash of custom-build packages that are required
#  (packageName => version )
#
sub customBuildPackages {
    my $self=shift;
    my $platform=shift;

    my @keys=( "dependencies::custom",
               "dependencies::custom::".$platform->name(),
               "dependencies::custom::".$platform->platform() );
    my $deps={};
    foreach my $key ( @keys ) {
        # -- custom packages must have a version
        foreach my $p ( $self->{config}->list($key) ) {
            die("entries in a dependencies::custom list must specify a version");
        }
        $deps=$self->_dependencies($key, $deps);
    }
    # remove any anulled with -
    foreach my $key ( keys %$deps ) {
        if( $key=~/^\-(.+)/ ) {
            delete $deps->{$1};
            delete $deps->{$key};
        }
    }
    return $deps;
}

sub platformPackages {
    my $self=shift;
    my $platform=shift;
    my $type=shift;

    # --- extract data
    my @keys=( "dependencies::".$type,
               "dependencies::$type"."::".$platform->name(),
               "dependencies::$type"."::".$platform->platform() );
    if( $type ne "optional") {
        unshift @keys,( "dependencies",
               "dependencies::".$platform->name(),
               "dependencies::".$platform->platform() );
    }
    my $deps={};
    foreach my $key ( @keys ) {
        $deps=$self->_dependencies($key, $deps);
    }
    # remove any anulled with -
    foreach my $key ( keys %$deps ) {
        if( $key=~/^\-(.+)/ ) {
            delete $deps->{$1};
            delete $deps->{$key};
        }
    }
    return $platform->packageInfo($self->_deparray($deps));
}

#
# add a package dependecy to the specified dependency list
#
sub addDependencies {
    my $self=shift;
    my $type=shift; # e.g. build, runtime, or empty string for "all"
    my $key=$self->_getSection($type);

    foreach my $item ( @_ ) {
        if( ! $item->hasVersionRestriction() )
        {
            $self->{config}->setList($key, $item->name() );
        }
        else {
            $self->{config}->setVar($key, $item->name(), $item->version() );
        }
    }
}

sub removeDependencies {
    my $self=shift;
    my $type=shift; # e.g. build, runtime, or empty string for "all"
    my $key=$self->_getSection($type);
    foreach my $item ( @_ ) {
        if( ! $item->hasVersionRestriction() )
        {
             $self->{config}->removeItemFromList($key,$item->name());
        }
        else {
             $self->{config}->removeVar($key,$item->name(), $item->version());
        }
    }
}

sub compareType {
    my $self=shift;
    my $type=shift; # e.g. build, runtime
    my $deps=shift; # A PackageDependencies object to compare with

    foreach my $section ( $self->{config}->sections("^dependencies:?.*") )
    {
        # -- filter out incorrect types
        if( $section=~/^dependencies::(.*?)::.*/ ) {
            next, if( $1 ne $type );
        }
        elsif( $section=~/^dependencies::(.*)/ ) {
            if( $1 ne $type ) {
                next, if ( grep( /$1/, @{$self->{types}}) );
            }
        }

        # -- check the versioned deps
        foreach my $var ( sort($self->{config}->vars($section)) ) {
            if( ! defined $deps->{config}->var($section, $var) || 
                $self->{config}->var($section, $var) ne $deps->{config}->var($section, $var) ) {
                return 0;
            }
        }
        # -- check dependency lists
        my @depList=sort($deps->{config}->list($section));
        my @list=sort($self->{config}->list($section));
        return 0, if($#depList != $#list);
        my $i=-1;
        while( ++$i < $#depList ) {
            return 0, if( $depList[$i] ne $list[$i]);
        }
    }
    return 1;
}

sub _dependencies {
    my $self=shift;
    my $key=shift;
    my $deps=shift;

    my @deps;
    foreach my $p ( $self->{config}->list($key) ) {
        $deps->{$p}="";
    }
    foreach my $var ( $self->{config}->vars($key) ) {
        $deps->{$var}=$self->{config}->var($key, $var);
    }
    return $deps;
}

# convert name, version hash to array of hashes with name,key tags
sub _deparray {
    my $self=shift;
    my $dep=shift;
    my @deps;
    for( keys %{$dep} ) {
       push @deps, { name=>"$_", version=>$dep->{$_} };
    }
    return @deps;
}

sub expandVars {
    my $self=shift;
    my $string=shift;
    my $platform=shift;
    my $mode=shift;

    my @deps=$self->platformPackages($platform,$mode);
    for my $pkg ( @deps ) {
        $string=$pkg->expandString($string);
    }
    return $string;
}

sub _getSection {
    my $self=shift;
    my $type=shift;

    my $key="dependencies";
    if( defined $type && $type ne "" && $type ne "all" ) {
        $key.="::$type";
    }
    return $key;
}
