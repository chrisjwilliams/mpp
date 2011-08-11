# ----------------------------------
# class ProjectInfo
# Description:
#   Contains all information about a project
#-----------------------------------
# Methods:
# new() :
# installDirs(Platform) : return a list of all the installation directories for the project on the specified platform
# searchSection(@sectionList) : return the first section that exists (as a hash)
#-----------------------------------

package ProjectInfo;
use PackageDependencies;
use strict;
use Carp;
use ContentList;
use SrcPack;
use Environment;
use MppClass;
our @ISA=qw /MppClass/;
1;

sub new {
    my $class=shift;
    my $self=$class->SUPER::new(@_);
    $self->{config}=shift;
    $self->{projectDir}=shift;
    $self->{name}=shift;
    $self->{version}=shift;
    $self->{parent}=shift;

    $self->{type}=$self->{config}->var("project","type") || "build";
    die("unknown build type '".$self->{type}."'"), if ( ! ($self->{type}=~/pack/i || $self->{type}=~/build/i ) );
    $self->{toBuild}=1; # assume buildable
    # --- check minimal information and set defaults
    if( ! defined $self->{config}->var("project","name") ) {
        $self->{config}->setVar("project","name",$self->{name});
    }
    else {
        $self->{name}=$self->{config}->var("project","name");
    }
    if( ! defined $self->{config}->var("project","version") ) {
        $self->{config}->setVar("project","version",$self->{version});
    }
    else {
        $self->{version}=$self->{config}->var("project","version");
    }
    # --- licence
    my $licence=$self->{config}->var("project","licence");
    if( ! defined $licence ) {
        $licence=$self->{config}->var("project","license"); # american spelling?
    }
    warn( "licence conditions need to be defined for this project (".($self->{name})." ".($self->{version}).")"), if( ! defined $licence );
    $self->{licence}=$licence;

    # -- set up expansion variables
    $self->{env}=Environment->new( { name=>"$self->{name}",
                                     version=>"$self->{version}" } );

    bless $self, $class;
    return $self;
}

sub type {
    my $self=shift;
    return $self->{type};
}

sub arch {
    my $self=shift;
    return $self->{config}->var("project","arch");
}

sub conflicts {
    my $self=shift;
    return $self->{config}->var("project","conflicts");
}

sub replaces{
    my $self=shift;
    return $self->{config}->var("project","replaces");
}

sub buildable {
    my $self=shift;
    return $self->{toBuild};
}

sub extraLibraryDirs {
    my $self=shift;
    return $self->contents()->dirType("shared");
}

sub prePackaged {
    my $self=shift;
    my $pack=$self->{projectDir}."/";
    my @files=(); #$self->{config}->list("package");
    if( $self->{config}->definedSection("package") ) {
        for( $self->{config}->var("package","file"), $self->{config}->list("package") ) {
            if( -f $pack.$_ ) {
               push @files, $pack.$_;
            }
            else {
               print "No package '$_' available in $pack\n";
            }
         }
         if( $#files >= 0 ) {
            require Package::Package;
            my $pkg=Package::Package->new( { name=>$self->{name},
                        version=>$self->{version},
                        type=>$self->{config}->var("package","type")
                    } );
            $pkg->setFiles(@files), if (@files);
            return $pkg;
        }
    }
    return ();
}

# contents( Platform )
# returns the appropriate ContentList object for the specified platform
#
sub contents {
    my $self=shift;
    if ( ! defined $self->{contents} ) {
        $self->{contents}=INIConfig->new();
        $self->{contents}->mergeSection("install",$self->{config});
        for ( $self->{config}->sections("^install::.*") ) {
            my $tag=$self->expandVars($_);
            $self->{contents}->mergeSection($tag,$self->{config},$_);
        }
        for ( $self->{config}->sections("^install_.*::.*") ) {
            my $tag=$self->expandVars($_);
            $self->{contents}->mergeSection($tag,$self->{config},$_);
        }
    }
    return ContentList->new( $self->{contents}, @_);
}

sub env {
    my $self=shift;
    return $self->{env}->env();
}

sub setEnv {
    my $self=shift;
    my $var=shift;
    $self->{env}->set($var,shift);
}

sub name {
    my $self=shift;
    my $platform=shift;
    if( defined $platform ) {
        my @keys=( "project", "project::".$platform->name(),
                   "project::".$platform->platform()
                 );
        foreach my $key ( reverse @keys ) {
            my $nm = $self->{config}->var($key,"name");
                return $nm, if( defined $nm && $nm ne "" );
            }
    }
    else {
        return $self->{name};
    }
}

sub projectDir {
    my $self=shift;
    return $self->{projectDir};
}

sub variants {
    my $self=shift;
    if( ! defined $self->{variants} ) {
        @{$self->{variants}}=();
         foreach my $name ($self->_variantList()) {
             my $var=$self->variant($name);
             if( ( $var->buildable()) && $var->isLeaf() ) {
                 push@{$self->{variants}}, $var;
             }
         }
    }
    return @{$self->{variants}};
}

#
# return a list of virtual packages that this project provides
#
sub provides {
    my $self=shift;
    my $p=$self->{config}->var("project","provides");
    my @prov=();
    @prov=split(/,/,$p ), if ( defined $p );
    return @prov;
}

#
# return a list of files that are likely to be in the build area
# but do not form part of the packaged distribution
#
sub excludeFiles {
    my $self=shift;
    my $platform=shift;

    if( ! defined $self->{excludeFiles} ) {
        my @dirs;
        foreach my $p ( $self->subpackages() ) {
            push @dirs, $p->allFiles($platform);
        }
        my %seen = ();
        @{$self->{excludeFiles}} = grep { ! $seen{$_} ++ } @dirs;
    }
    return (@{$self->{excludeFiles}});
}

#
# return a list of all files in this and all subpackages
#
sub allFiles {
    my $self=shift;
    my $platform=shift;

    my $tag=(defined $platform)?$platform:"none";
    if( ! defined $self->{allFiles}{$tag} ) {
        my @files=();
        my $content=$self->contents($platform);
        for( ($content->files()) ) {
            push @files, $_->[1];
        }
        foreach my $p ( $self->subpackages() ) {
            push @files, $p->allFiles();
        }
        my %seen = ();
        @{$self->{allFiles}{$tag}} = grep { ! $seen{$_} ++ } @files;
    }
    return (@{$self->{allFiles}{$tag}});
}


sub isLeaf {
    my $self=shift;
    if( ! defined $self->{isLeaf} ) {
        my @vars=$self->_variantList();
        if( @vars ) {
            $self->{isLeaf}=0;
        }
        else {
            $self->{isLeaf}=1;
        }
    }
    return $self->{isLeaf};
}

#
# return the first section found from a list of sections
#
sub searchSectionList {
    my $self=shift;

    for( @_ ) {
        if( $self->{config}->definedSection($_) ) {
            return ($self->{config}->list($_));
        }
    }
    return ();
}
#
# return the first occurance of a specified variable
# from the provided section list
# usage:
# searchInfo( variable_name, @section_keys);
sub searchInfo {
    my $self=shift;
    my $name=shift;

    my @keys=@_;
    my $tag;
    my $val;
    do {
        $tag=shift @keys;
        $val = $self->{config}->var($tag,$name);
    } while( ! defined $val && $#keys >= 0 );
    if( defined $val ) {
        $val=$self->expandVars($val);
    }
    return $val;
}

#
# returns an Environment Object composed of all
# the values in the provided sections
#
sub sectionEnvironment {
    my $self=shift;
    my @sections=@_;
    my $env=Environment->new();
    foreach my $s ( @sections ) {
        $env->merge( $self->{config}->section($s) );
    }
    return $env;
}

#
# return a hash containing the value of the specified 
# variable, for each section section matching the 
# specified pattern. The first value found working up the
# tree will be returned
#
sub findVars {
    my $self=shift;
    my $pattern=shift;
    my $name=shift;
    my @keys=$self->{config}->sections($pattern);
    my $val={};
    foreach my $tag ( @keys ) {
        if( defined $self->{config}->var($tag,$name) )
        {
            $val->{$tag}=$self->{config}->var($tag,$name);
        }
    }
    if( defined $self->{parent} ) {
        # find sections that match from the parent
        my $v=$self->{parent}->findVars($pattern,$name);
        for( keys %{$v} ) {
            $val->{$_}=$v->{$_}, if( ! defined $val->{$_} );
        }
    }
    return $val;
}

sub subpackage {
    my $self=shift;
    my $variant=shift;
    if( ! defined $self->{subpackagesObj}{$variant} ) {
        my $file=$self->{config}->var("subpackages",$variant);
        if( ! defined $file ) {
            $file=$self->{projectDir}."/config-$variant.ini";
        }
        elsif( $file!~/^[\\\/].+/ ) {
            $file=$self->{projectDir}."/".$file; 
        }
        croak "variant \"$variant\" configuration file does not exist ($file)", if ( ! -f $file );
        my $tconf=INIConfig->new($file);
        if( ! defined $tconf->var("project","name") ) {
            $tconf->setVar("project","name", $self->{name}."-".$variant );
        }

        my $vconf=$self->{config}->clone();
        $vconf->clearSection("subpackages");
        $vconf->clearSection("variants");
        # - do not propagate install:: sections
        foreach my $sec ( $vconf->sections('install(::|$)') ) {
            $vconf->clearSection($sec);
        }
        # - do not propogate provides section
        $vconf->setVar("project","provides",undef);
        # - remove build:: sections
        foreach my $key ( $tconf->sections('build(::|$)') ) {
            $vconf->clearSection($key);
        }
        $vconf->merge($tconf);
        $self->{subpackagesObj}{$variant}=new ProjectInfo($vconf, $self->{projectDir}, undef,undef, $self);
    }
    return $self->{subpackagesObj}{$variant};
}

sub variant {
    my $self=shift;
    my $variant=shift;
    if( ! defined $self->{variant}{$variant} ) {
        my $vconf=$self->{config}->clone();
        $vconf->clearSection("variants");
        my $file=$self->{config}->var("variants",$variant);
        if( ! defined $file ) {
            $file=$self->{projectDir}."/config-$variant.ini";
        }
        elsif( $file!~/^[\\\/].+/ ) {
            $file=$self->{projectDir}."/".$file; 
        }
        croak "variant \"$variant\" configuration file does not exist ($file)", if ( ! -f $file );
        my $tconf=INIConfig->new($file);
        if( ! defined $tconf->var("project","name") ) {
            $tconf->setVar("project","name", $self->{name}."-".$variant );
        }

        # we need a build cmd only if it is different from our parent
        # and/or we have different build dependencies
        my $needcmd=0;
        # --- check build blocks
        foreach my $key ( grep( /^build:?.*/g, $tconf->sections() ) ) {
            foreach my $var ( $tconf->vars($key) ) {
                if(! defined ($vconf->var($key, $var)) || 
                   $vconf->var($key, $var) ne $tconf->var($key, $var)) {
                   $needcmd=1; last;
                }
            }
        }
        if( ! $needcmd ) {
            # --- check deps
            my $deps=PackageDependencies->new($tconf);
            if( ! $deps->compareType("build", $self->dependencies() )) {
                $needcmd=1;
            }
        }
        $vconf->merge($tconf);
        if( ! $needcmd ) {
            foreach my $key ( grep( /^build:?.*/g, $vconf->sections() ) ) {
                $vconf->setVar($key,"cmd", undef );
            }
        }
        else {
            # -- grab the build command from our parent
            my $vars=$self->findVars("build:?.*", "cmd");
            for ( keys %{$vars} ) {
                $vconf->setVar($_,"cmd", $vars->{$_});
            }
        }
        $self->{variant}{$variant}=new ProjectInfo($vconf, $self->{projectDir}, undef,undef, $self);
        $self->{variant}{$variant}->{toBuild}=$needcmd;
    }
    return $self->{variant}{$variant};
}

sub subpackages {
    my $self=shift;
    if( ! defined $self->{subpackages} ) {
        @{$self->{subpackages}}=();
         foreach my $name ($self->_subpackageList()) {
             my $var=$self->subpackage($name);
             #if( (! $var->buildable()) && $var->isLeaf() ) {
             push@{$self->{subpackages}}, $var;
                 #}
         }
    }
    return @{$self->{subpackages}};
}

sub vendor {
    my $self=shift;
    my $vendor=$self->{config}->var("project","vendor");
    if( ! defined $vendor ) {
        $vendor="MPP Build Service";
    }
    return $vendor;
}

sub version {
    my $self=shift;
    return $self->{version};
}

sub summary {
    my $self=shift;
    return $self->{config}->var("project","description");
}

sub group {
    my $self=shift;
    my $gp=$self->{config}->var("project","group");
    $gp="application", if( ! defined $gp );
    return $gp;
}

sub description {
    my $self=shift;
    return $self->{config}->list("description");
}

sub licence {
    my $self=shift;
    return $self->{licence};
}

sub srcDir {
    my $self=shift;
    my $src=$self->{config}->var("code","srcDirectory");
    #warn("warning no source directory (srcDirectory) defined"), if( ! defined $src );
    $src="src", if( ! defined $src );
    return $self->expandVars($src);
}

sub srcPack {
    my $self=shift;
    if( ! defined $self->{srcPack} ) {
        my $config=$self->{config}->section("code");
        my $config2={};
        for( keys %{$config} ) {
            $config2->{$_}=$self->expandVars($config->{$_});
        }
        if( defined $config2->{srcPack} ) {
            $config2->{srcPack}=$self->projectDir()."/".$config2->{srcPack};
            $self->{srcPack}=SrcPack->new($config2);
        }
    }
    return $self->{srcPack};
}

sub setPrefix {
    my $self=shift;
    $self->{env}->set("prefix",shift);
}

sub dependencies {
    my $self=shift;
    if( ! defined $self->{deps} )
    {
        $self->{deps}=PackageDependencies->new($self->{config});
    }
    return $self->{deps};
}

sub expandVars {
    my $self=shift;
    my $string=shift;
    if( defined $string ) {
        $string=$self->{env}->expandString($string);
        #foreach my $v ( keys %{$self->{env}} ) {
        #    $string=~s/(.*?)\$\{$v\}(.*?)/$1$self->{env}{$v}$2/g;
        #}
    }
    return $string;
}

sub installDirs {
    my $self=shift;
    my $platform=shift;

    if( ! defined $self->{installDirs} ) {
        my @dirs;
        push @dirs, $self->contents($platform)->dirs();
        foreach my $p ( $self->subpackages() ) {
            push @dirs, $p->installDirs($platform);
        }
        my %seen = ();
        @{$self->{installDirs}} = grep { ! $seen{$_} ++ } @dirs;
    }
    return (@{$self->{installDirs}});
}

sub _variantList {
    my $self=shift;
    my @vars=$self->{config}->list("variants");
    push @vars, $self->{config}->vars("variants");
    return @vars;
}

sub _subpackageList {
    my $self=shift;
    my @vars=$self->{config}->list("subpackages");
    push @vars, $self->{config}->vars("subpackages");
    return @vars;
}
