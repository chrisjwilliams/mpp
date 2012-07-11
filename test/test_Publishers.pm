# ----------------------------------------
#
# Unit test for the Publishers Class
#
# ----------------------------------------
#

package test_Publishers;
use File::Path;
use File::Sync qw( sync );
use TestUtils::TestPackage;
use TestUtils::MppApi;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self,$class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{api}=TestUtils::MppApi->new($self->{testConfigDir},$self->{tmpdir});
    $self->{pubfac}=$self->{api}->getPublisherFactory();
    $self->{tpack}=TestUtils::TestPackage->new($self->{testConfigDir},$self->{tmpdir});
    return $self;
}

sub tests
{
#    my $self=shift;
#    my @tests=();
#    foreach my $pub ( $self->{pubfac}->publishers() ) {
#        push @tests, "test_".$pub;
#    }
#    return @tests;
}

sub test_addNonExisting {
    my $self=shift;
    my $pub=shift;

    my $release="stableish";
    my $arch="amd64";

    eval {
        $pub->add($release, $self->{tmpdir}."/notHere");
    };
    if($@) {
        return 0;
    }
}

sub test_addRemovePackage {
    my $self=shift;
    my $pub=shift;
    
    my $release="stableish";
    my $arch="test_arch";

    # add the package and test the full structure exists
    my @types=$pub->packageTypes();
    foreach my $type ( @types ) {
        $pub->add($release, $self->{tpack}->getPackage($type) );
    }
    sync();

    # ------ test the repository info methods -------------
    # -- expect the arch for the added type/release
    {
        my @archs=$pub->architectures($release);
        die("architectures() method returning $#archs items"), if( $#archs != 0 || $archs[0] ne $arch );
    }
    {
        my @archs=$pub->architectures("rubbish");
        die("architectures() method returning $#archs items"), if( $#archs >= 0 );
    }

    # remove the package - ensure cleanup of empty structures
    #
    $pub->remove($release, $self->{tpack}->name() );
    sync();
    {
        my @archs=$pub->architectures($release);
        die("architectures() method returning $#archs items"), if( $#archs >= 0 );
    }

    return 0;

}

#
# AUTOLOAD makes list of tests for each publisher
#
sub AUTOLOAD {
    my $self=shift;
    
    return if our $AUTOLOAD !~ /::test_(.+)$/;
    my $name=$1;
    my $pub=$self->{pubfac}->getPublisher($name);
    die ("unable to instantiate publisher $pub" ), if( ! defined $pub );
    $self->test_addNonExisting($pub);
    $self->test_addRemovePackage($pub);
}
