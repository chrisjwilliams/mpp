# ----------------------------------
# class test_Publication
# Description:
#  Test the publication interfacr
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_Publication;
use Publication;
use TestUtils::MppApi;
use TestUtils::TestPlatform;
use TestUtils::TestProject;
use TestUtils::BuiltTestProject;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    return $self;
}

sub tests {
    return qw( test_init test_publishNoDeps test_publishWithDeps 
               test_platformSubstitution test_repositoryInstallPackage );
}

sub getAPI {
    my $self=shift;
    my $config=shift || new INIConfig;
    return TestUtils::MppApi->new( $self->{testConfigDir}, $self->{tmpdir}, $config );
}

sub getPublicationObject {
    my $self=shift;
    my $api=shift || $self->getAPI();
    my $config=shift || new INIConfig;
    $config->setVar("publication","name","TestName"), if( ! defined $config->var("publication","name") );
    return new Publication( $config, $api);
}

sub test_init {
    my $self=shift;

    # Use case:
    # No configuration at all
    # Expect:
    # die, complaining about missing config items
    eval { my $pub = new Publication(); };
    if(! $@) {
        die("expecting throw when no name supplied");
    }
    # Use case:
    # Name specified, but no api
    # Expect:
    # not to die, empty list when repository list requested
    eval { new Publication( new INIConfig({ name=>"TestName" }) ) };
    if(! $@) {
        die("expecting throw when no api object reference supplied");
    }

    # Use case:
    # Name specified, and api
    # Expect:
    # not to die, and reflet name configuration
    my $testRepo = "TestRepo";
    my $config=new INIConfig;
    my $mainconfig=new INIConfig;
    $mainconfig->setVar("repository::$testRepo","type","test");
    $mainconfig->setVar("repository::$testRepo","root",$self->{tmpdir});
    $config->setVar("publication","name", "ATestName" );
    {
        my $pub = new Publication( $config, $self->getAPI($mainconfig) );
        my $name=$pub->name();
        die("unexpected name: '$name'"), if( $name ne "ATestName" );
    }

    # Use case:
    # Name specified, and api, and a repository that does not exist
    # Expect:
    # to die on request for non-existing publication
    # return the repository object for those that do exist
    $config->setList("repositories","IdontExist", $testRepo );
    my $pub=$self->getPublicationObject($self->getAPI($mainconfig), $config);
    eval{ $pub->getRepository("IdontExist"); };
    if(! $@) {
        die("expected throw when requesting an unknown repository");
    }
    my $repo = $pub->getRepository($testRepo);
    die("returned an object of type '".(ref($repo))."'"), if( ! $repo->isa("Publishers::Test") );

}

sub test_publishNoDeps {
    my $self=shift;
    my $config = new INIConfig;
    my $testRepo = "TestRepo";
    $config->setList("repositories", $testRepo);
    my $mainconfig=new INIConfig;
    $mainconfig->setVar("repository::$testRepo","type","test");
    $mainconfig->setVar("repository::$testRepo","root",$self->{tmpdir});

    my $release="test";
    my $api=$self->getAPI($mainconfig);
    my $platform=new TestUtils::TestPlatform( $self->{tmpdir} );
    {
        # Use Case:
        # simple project with no dependencies, and already built
        # Expect:
        # repository to be called with package
        my $pub=$self->getPublicationObject($api,$config);
        my $proj=new TestUtils::BuiltTestProject($api, $self->{tmpdir}, $self->{testConfigDir}, $pub);
        my $report=$pub->publish($release, $proj, $platform);
        die("Expecting it to publish OK"), if($report->failed());
    }
    {
        # Use Case:
        # simple project with no dependencies, not yet built
        # Expect:
        # do nothing, return a report that indicates failure with a useful message
        my $pub=$self->getPublicationObject($api,$config);
        $pub->setVerbose(1);
        my $proj=new TestUtils::TestProject($api, $self->{tmpdir}, 
                                            $self->{testConfigDir}, $pub );
        my $report=$pub->publish($release, $proj, $platform);
        if(!$report->failed()) {
            die("expecting throw when attempting to publish a project that has not been built");
        }
    }
}

sub test_publishWithDeps {
    my $self=shift;
}

sub test_platformSubstitution {
    my $self=shift;
    my $api=$self->getAPI();
    {
        # Use Case:
        # call with a platform name & empty usecase & no substiututes
        # Expect:
        # return original name
        my $name="testPlatform";
        my $config = new INIConfig;
        my $pub=$self->getPublicationObject($api,$config);
        my $res=$pub->platformSubstitution($name);
        die("Expecting name to be unchanged"), if($res ne $name );
    }
    my $uc="test";
    {
        # Use Case:
        # call with a platform name & valid usecase & no substiututes
        # Expect:
        # return original name
        my $name="testPlatform";
        my $config = new INIConfig;
        my $pub=$self->getPublicationObject($api,$config);
        my $res=$pub->platformSubstitution($name, $uc);
        die("Expecting name to be unchanged"), if($res ne $name );
    }
    my $sname="subsPlatform";
    {
        # Use Case:
        # call with a platform name with a global substitution
        # Expect:
        # return substitute
        my $name="testPlatform";
        my $config = new INIConfig;
        $config->setVar("platform::$name", "platform", $sname);
        my $pub=$self->getPublicationObject($api,$config);
        # - no usecase
        my $res=$pub->platformSubstitution($name);
        die("Expecting name to be changed : got $res"), if( $res ne $sname );
        # - any usecase
        my $res2=$pub->platformSubstitution($name, $uc);
        die("Expecting name to be changed : got $res2"), if($res2 ne $sname );
    }
    {
        # Use Case:
        # call with a platform name with a usecase specific substitution
        # Expect:
        # return substitute for the specified usecase only
        my $name="testPlatform";
        my $config = new INIConfig;
        $config->setVar("platform::$name", $uc."Platform", $sname);
        my $pub=$self->getPublicationObject($api,$config);
        # - no usecase
        my $res=$pub->platformSubstitution($name);
        die("Expecting name to be unchanged : got $res"), if( $res ne $name );
        # - substitute usecase
        my $res2=$pub->platformSubstitution($name, $uc);
        die("Expecting name to be changed : got $res2"), if($res2 ne $sname );
        # - other usecase
        my $res3=$pub->platformSubstitution($name, "other");
        die("Expecting name to be unchanged : got $res3"), if($res3 ne $name );
    }
}

sub test_repositoryInstallPackage {
    my $self=shift;
    
    my $config = new INIConfig;
    my $pub=$self->getPublicationObject($self->getAPI(), $config);
    $pub->setVerbose(1);
    my $release="unittest";
    my $platform=new TestUtils::TestPlatform( $self->{tmpdir} );
    {
        # Use Case:
        # call on non-existing repository
        # Expect:
        # throw with suitable error message
        eval {
            $pub->generateInstallationPackage($platform, $release);
        };
        die "expecting throw when the repository does not exist", if( !$@ );
    }
    my @packagelist=qw(testrepository_repo);
    {
        # Use Case:
        # call on existing repository, packages already exist, but not published
        # Expect:
        # return list of packages
        my @packs=$pub->generateInstallationPackage($platform, $release);
        die "expecting @packagelist, got @packs", if( "@packagelist" ne "@packs" );
    }
}
