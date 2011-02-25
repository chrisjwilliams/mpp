# ----------------------------------
# class PackageFactory
# Description:
#    Create PackageInfo objects
#-----------------------------------
# Methods:
# new() :
#-----------------------------------

package PackageFactory;
use MppClass;
use INIConfig;
our @ISA=qw/MppClass/;
use strict;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    $self->{config}=shift;
    $self->{platformloc}=shift;
    my $data=$self->{platformloc}."/Data";
    $self->{dataPath}=File::SearchPath->new($data);
    $self->verbose("\nInitiating PackageFactory");
    @{$self->{modes}}=qw(build runtime);
    bless $self, $class;
    return $self;
}

sub modes {
    my $self=shift;
    return (@{$self->{modes}});
}

sub getPackage {
    my $self=shift;
    my $platform=shift;
    my $name=shift;
    my $version=shift;

    my $packdb=$self->_loadPlatformData($platform);
    my $vertag=$version;
    $vertag="unknown", if( ! defined $vertag || $vertag eq "");
    $self->verbose("getPackage($name, $vertag)");

    my @modes=@{$self->{modes}};
    if( ! defined $self->{packages}{$name}{$vertag}{$platform} ) {
        my $tag="pack::$name";
        my $tagver=$tag."::$vertag";
        my @sections=$tag; #=($packdb->section($tag));
        if( $vertag eq "unknown" ) {
            # look for the latest version available
            my @packs=reverse(sort($packdb->sections($tag."::.+")));
            push @sections, $packs[0], if(defined $packs[0]);
        }
        else {
            push @sections,$tagver;
        } 
        my $pkg=PackageInfo->new($name,$version);
        # define here to avoid problems with circular dependencies
        $self->{packages}{$name}{$vertag}{$platform}=$pkg;

        if( ! $packdb->definedSection("\Q$tag\E(::.+)?") ){
            $self->verbose("no sections for $tag defined");
            # set up so that every mode returns the
            # unmodified package name
            $pkg->setPackageNames($name);
        }
        else {
            my $env=Environment->new();
            # environments inherit from the main package
            foreach my $s ( @sections ) {
                $self->verbose("merging section $s");
                $env->merge( $packdb->section($s) );
            }
            # add listed packages for each mode
            $tag=$sections[$#sections];
            foreach my $mode ( @modes ) {
                # remove mode package name keys from the package env
                $env->deleteVar($mode);
                my $pk=$packdb->var($tag,$mode);
                if( $pk ) {
                    $self->verbose("Setting package name for mode '$mode' to $pk for package $tag");
                    $pkg->setPackageNamesType($mode, $pk );
                }
            }
            # add any required packages listed
            $self->verbose("tag $tag not defined"), if( ! $packdb->definedSection("\Q$tag\E") );
            for($packdb->list($tag)) {
                $self->verbose("\nadding dependency $_");
                if( $_ eq $name ) {
                    $pkg->setPackageNames($_);
                }
                else {
                    $pkg->addDependency($self->getPackage($platform, $_));
                }
            }

            # add environment info
            $pkg->merge($env);
        }
    }
    return $self->{packages}{$name}{$vertag}{$platform};
}

sub getDataBase {
    my $self=shift;
    my $platform=shift;

    my $packdb=$self->_loadPlatformData($platform);
    return $packdb;
}

sub _loadPlatformData {
    my $self=shift;
    my $platform=shift;

    if( ! defined $self->{packdb}{$platform} ) {
        my $db=$self->{config}->var("packages", "database");
        my @names;
        if( ! defined $db || $db eq "" ) {
            # -- look for the default databases
            if( defined $self->{config}->var("packager","type") ) {
                push @names, $platform->platform()."_".$platform->{config}->var("packager","type");
                push @names, $platform->platform()."_".$platform->arch()."_".$platform->{config}->var("packager","type");
            }
            push @names, $platform->platform()."_".$platform->arch();
            push @names, $platform->platform();
        }
        else {
            push @names, $db;
        }
        my @dbs=$self->{dataPath}->find(@names);
        $self->verbose("Loading Platform data from @dbs");
        $self->{packdb}{$platform}=new INIConfig(reverse @dbs);
    }
    return $self->{packdb}{$platform};
}
