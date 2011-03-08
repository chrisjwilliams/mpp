# ----------------------------------
# class test_PublisherFactory
# Description:
# Unit test for the publiasherFactory module
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_PublisherFactory;
use strict;
use PublisherFactory;
use TestUtils::MppApi;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    #$self->{api}=TestUtils::MppApi->new($self->{testConfigDir},$self->{tmpdir});
    $self->{src}=$FindBin::Bin."/../Publishers";
    return $self;
}

sub tests {
    return qw( test_typeExists test_typeInstallerExists test_getPublisherFail test_getPublisher test_getPackageInstaller);
}

sub test_typeExists {
    my $self=shift;
    my $config=INIConfig->new();
    my $pf=PublisherFactory->new($self->{src},$config);
    die "unable to find type apt", if( ! $pf->typeExists("apt") );
    die "found non existing type", if( $pf->typeExists("Idontexist") );
}

sub test_typeInstallerExists {
    my $self=shift;
    my $config=INIConfig->new();
    my $pf=PublisherFactory->new($self->{src}, $config);
    die "unable to find type apt", if( ! $pf->typeInstallerExists("apt") );
    die "found non existing type", if( $pf->typeInstallerExists("Idontexist") );
}

sub test_getPublisherFail {
    my $self=shift;
    # -- empty configuration
    my $config=INIConfig->new();
    my $pf=PublisherFactory->new($self->{src},$config);
    eval {
        $pf->getPublisher("Idontexist");
    };
    if(!$@)
    {
        die "expecting getPublisher to die when called with non existing";
    }
    # -- try get a non-existing publisher type
    my $type=$pf->getPublisherType("Idontexist");
    die "expecting getPublisherTyoe to return undef when called with non existing",  if ( defined $type );
    # -- add a publisher of undefined type
    eval {
        $pf->getPublisher("test_pub");
    };
    if(!$@)
    {
        die "expecting getPublisher to die when called with unspecified type";
    }
}

sub test_getPublisher {
    my $self=shift;
    # -- empty configuration
    my $config=INIConfig->new();
    $config->setVar("publisher::test_pub","root",$self->{tmpdir}."/simple");
    $config->setVar("publisher::test_pub","type","simple");
    my $pf=PublisherFactory->new($self->{src},$config);
    
    my $pub=$pf->getPublisher("test_pub");
    die "unable to find publisher 'test_pub'", if (! defined $pub);
    my $pub2=$pf->getPublisherType("simple");
    die "unable to find publisher of type 'simple'", if (! defined $pub2);
}

sub test_getPackageInstaller {
    my $self=shift;
    # -- empty configuration
    my $config=INIConfig->new();
    my $pf=PublisherFactory->new($self->{src},$config);
    
    my $pub1=$pf->getPackageInstaller("apt");
    die "unable to find PackageInstaller 'apt'", if (! defined $pub1);
    # -- call to same should return the same object
    my $pub2=$pf->getPackageInstaller("apt");
    die "unable to find PackageInstaller 'apt'", if (! defined $pub2);
    die "different objects returned", if ($pub1 != $pub2);
}
