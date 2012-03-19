# ----------------------------------
# class test_ProjectInfo
# Description:
#  Unit test for the ProjectInfo class
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_ProjectInfo;
use strict;
use INIConfig;
use ProjectInfo;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{cfgDir}=$self->{testConfigDir}."/test_project";
    return $self;
}

sub tests {
    return qw( test_instantiate test_sectionEnvironment test_overridenVersion test_leaf test_variants test_allfiles);
}

sub test_instantiate {
    my $self=shift;
    # Use Case:
    # Instantiate the object where no name or version is provided in the config
    # Expect:  use the name/version provided in the contructor
    my $config=INIConfig->new();
    $config->setVar("project","licence","GPL");
    my $pinfo=ProjectInfo->new($config, $self->{cfgDir}, "testname", "testversion");
    my $name=$pinfo->name();
    die("wrong name $name") , if ( $name ne "testname" );
    my $version=$pinfo->version();
    die("wrong version $version") , if ( $version ne "testversion" );
}

sub test_overridenVersion {
    my $self=shift;
    # Use Case:
    # Instantiate the object where name and version are provided in the config
    # Expect:  use the name/version provided in the config ignoring those in the constructor
    my $config=INIConfig->new($self->{testConfigDir}."/test_project/install.ini");
    my $pinfo=ProjectInfo->new($config, $self->{cfgDir}, "testname", "testversion");
    my $name=$pinfo->name();
    die("wrong name $name") , if ( $name ne "test_project" );
    my $version=$pinfo->version();
    die("wrong version $version") , if ( $version ne "1.2.3" );
}

sub test_leaf {
    my $self=shift;
    {
        # Use case:
        # A single config file with no variants
        # Expect: isLeaf() = true, buildable()=true
        my $config=INIConfig->new($self->{testConfigDir}."/test_project/install.ini");
        my $pinfo=ProjectInfo->new($config, $self->{cfgDir}, "testname", "testversion");
        die("expecting a leaf"), if( ! $pinfo->isLeaf() );
        die("expecting buildable"), if( ! $pinfo->buildable() );
    }
    {
        # Use case:
        # variants
        # Expect: isLeaf() = false, buildable()=true
        my $config=INIConfig->new($self->{testConfigDir}."/test_project/install-variants.ini");
        my $pinfo=ProjectInfo->new($config, $self->{cfgDir}, "testname", "testversion");
        die("not expecting a leaf"), if( $pinfo->isLeaf() );
        die("expecting buildable"), if( ! $pinfo->buildable() );
        my $var1=$pinfo->variant("variant1");
        die("not expecting a leaf"), if( $var1->isLeaf() );
        die("not expecting buildable"), if( $var1->buildable() );
        my $var2=$pinfo->variant("variant2");
        die("expecting a leaf"), if( ! $var2->isLeaf() );
        die("not expecting buildable"), if( $var2->buildable() );
    }
}

sub test_variants {
    my $self=shift;
    my $config=INIConfig->new($self->{testConfigDir}."/test_project/install-variants.ini");
    my $pinfo=ProjectInfo->new($config, $self->{cfgDir}, "testname", "testversion");
    {
        # -- test top level variants list
        # two defaults and aone overrideen file name
        my @variants=sort($pinfo->_variantList());
        #my @expect=qw(variant1 variant2 variant3);
        my @expect=qw(variant1);
        die("wrong # of variants returned $#variants, expecting $#expect") , if ( $#variants != $#expect );
        my $i=-1;
        while( ++$i <= $#expect ) {
            die( "expecting variant ".($expect[$i]+1)." got ".($variants[$i]+1)."\n"), if ($expect[$i] ne $variants[$i]);
        }
    }
    # -- variant 1 has several sub variants and uses a default name
    my $var1=$pinfo->variant("variant1");
    my $varname1=$var1->name();
    die("var1 name not correct - got $varname1"), if ( $varname1 ne "test_project-variant1");
    {
        # -- test variant1 varaints list
        my @variants=sort($var1->_variantList());
        my @expect=qw(variant1a variant1b variant1c);
        die("wrong # of variants returned $#variants, expecting $#expect") , if ( $#variants != $#expect );
        my $i=-1;
        while( ++$i <= $#expect ) {
            die( "expecting variant ".($expect[$i]+1)." got ".($variants[$i]+1)."\n"), if ($expect[$i] ne $variants[$i]);
        }
    }
    # --- test sub variants are instantiated OK
    my $var1a=$var1->variant("variant1a");
    my $var1acmd=$var1a->{config}->var("build::localhost","cmd");
    my $varname1a=$var1a->name();
    die("variant1a name not correct - got $varname1a"), if ( $varname1a ne "variant1a-defined");
    die("variant1a - expected build cmd not defined"), if ( ! defined $var1acmd );

    # --- variant1b 
    # no dep changes or build specific options
    my $var1b=$var1->variant("variant1b");
    my $varname1b=$var1b->name();
    die("variant1b name not correct - got $varname1b"), if ( $varname1b ne "test_project-variant1-variant1b");
    #var1b should not have a build cmd
    my $var1bcmd=$var1b->{config}->var("build","cmd");
    my $var1bcmdh=$var1b->{config}->var("build::localhost","cmd");
    die("variant1b - unexpected build cmd ($var1bcmd)"), if ( defined $var1bcmd );
    die("variant1b - unexpected build::localhost cmd ($var1bcmdh)"), if ( defined $var1bcmdh );

    # --- variant1c 
    # dependents have changed so we expect a build cmd
    my $var1c=$var1->variant("variant1c");
    my $varname1c=$var1c->name();
    die("variant1c name not correct - got $varname1c"), if ( $varname1c ne "test_project-variant1-variant1c");
    my $var1ccmd=$var1c->{config}->var("build::localhost","cmd");
    die("variant1c - expected build cmd not defined"), if ( ! defined $var1ccmd );

    # --- variant 3 is taken from a non-default file and has a defined name
    my $var3=$pinfo->subpackage("variant3");
    my $varname3=$var3->name();
    die("variant3 name not correct - got $varname3"), if ( $varname3 ne "special-variant3");
    my $var3content=$var3->contents();
    die( "contents not provided" ), if ( ! defined $var3content );
    
    # --- check subpackages
    {
        my @subpkg=();
        for( $pinfo->subpackages()) {
            push @subpkg, $_->name();
        }
        my @expectedsubpack=sort(qw(special-variant3 test_project-variant2));
        @subpkg=sort(@subpkg);
        die( "subpackages: expected ".($#expectedsubpack+1)." elements, got ".($#subpkg+1)." (@subpkg)" ), if( $#expectedsubpack ne $#subpkg);
        my $i=-1;
        while( ++$i <= $#expectedsubpack ) {
            die( "expecting subpackage ".($expectedsubpack[$i]+1)." got ".($subpkg[$i]+1)."\n"), if ($expectedsubpack[$i] ne $subpkg[$i]);
        }
    }
}

sub test_allfiles {
    my $self=shift;
    my $config=INIConfig->new($self->{testConfigDir}."/test_project/install-subpackages.ini");
    my $pinfo=ProjectInfo->new($config, $self->{cfgDir}, "testname", "testversion");

    my @files=sort($pinfo->allFiles());
    my @allExpected=sort(qw(/usr/wibble2 /usr/bin ${install::bin}/hello.pl ${install::bin}/subbin/hello.pl ${install::lib}));
    die("installed files expected (@allExpected), got (@files)"), if ( "@allExpected" ne "@files");
    my @excludefiles=sort($pinfo->excludeFiles());
    my @excludeExpected=sort(qw(${install::lib}));
    die("exclude files expected (@excludeExpected), got (@excludefiles)"), if ( "@excludeExpected" ne "@excludefiles");
}

sub test_sectionEnvironment {
    my $self=shift;
    my $config=INIConfig->new($self->{testConfigDir}."/test_project/testSectionEnvironment.ini");
    my $pinfo=ProjectInfo->new($config, $self->{cfgDir}, "testname", "testversion");

    my $env=$pinfo->sectionEnvironment("sectiona","sectionb","sectionc");
    my $tenv=Environment->new( { var1=>"sectiona1",
                                 var2=>"sectionb2",
                                 var3=>"sectionc3",
                                 var4=>"sectionc4sectiona1",
                                 var5=>"sectiona5"
                               }
    );
    my $size=$env->size();
    die("environment returned $size elements"), if( $size != $tenv->size());
    my $diff=$env->diff($tenv);
    $size=$diff->size();
    die("environment unexpected $size elements\n\t".($diff->dump(\*STDOUT))), if( $size != 0 );
}
