# ----------------------------------
# class MppPublisher::test::test_DownloadClient
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_DownloadClient;
use MppPublisher::DownloadClient;
use TestUtils::MppApi;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{api}=TestUtils::MppApi->new($self->{testConfigDir}, $self->{tmpdir});
    $self->{platformM}=$self->{api}->getPlatformManager();
    $self->{localhost}=$self->{platformM}->getPlatform("localhost");
    return $self;
}

sub tests {
    return qw( test_addRepository test_getPackage );
}

sub test_addRepository {
    my $self=shift;
    my $dc=$self->_init();
    my @repos=$dc->reposOnline();
    my @erepos=qw(test_repo test_repo2);
    die("expecting @erepos, got @repos"), if( "@repos" ne "@erepos" );

    # -- only one release for each repository allowed
    #eval {
    #    $dc->addRepository("test_repo","release2");
    #}
    #if(!$@) {
    #    die("expecting throw for multiple release definitions on same repository");
    #}
}

sub test_getPackage {
    my $self=shift;
    my $dc=$self->_init();
    $dc->getPackage("package1","version1");
}

sub _init {
    my $self=shift;
    my $dc=MppPublisher::DownloadClient->new($self->{tmpdir},$self->{localhost});
    my $baseurl="file:/".$self->{tmpdir};
    $dc->addRepository("test_repo","$baseurl","release1");
    $dc->addRepository("test_repo2","$baseurl","release2");
    return $dc;
}
