# ----------------------------------------
#
# Unit test Base Class for Packagers tests
#
# ----------------------------------------
#

package TestUtils::TestPackager;
use TestUtils::MppApi;
use File::Path;
use File::Copy::Recursive;
use File::Copy;
use File::Sync qw(sync);
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self,$class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{api}=TestUtils::MppApi->new( $self->{testConfigDir}, $self->{tmpdir} );
    $self->{platformM}=$self->{api}->getPlatformManager();
    $self->{localhost}=$self->{platformM}->getPlatform("localhost");
    die( "Error initilising localhost platform" ), if ! defined $self->{localhost};

    # -- create a copy of the project configuration directory
    $self->{configSrcDir}=$self->{testConfigDir}."/test_project";
    my $dh=DirHandle->new($self->{configSrcDir}) or die "unable to open dir ".$self->{configSrcDir};
    my @files=$dh->read();
    foreach my $file ( @files ) {
        next, if( $file=~/^\.+/);
        next, if( ! -f $self->{configSrcDir}."/".$file );
        copy($self->{configSrcDir}."/".$file, $self->{tmpdir}."/".$file );
    }


    # -- expected values
    @{$self->{expectedcontent}}=sort(qw(/usr/bin/hello.pl /usr/bin/subbin/hello.pl /usr/lib/lib1.so /usr/lib/lib1.so.0 /usr/lib/lib2.so /usr/lib/lib2.so.0 /usr/lib/lib3.a /usr/lib/lib3.a.0 /usr/lib/lib3.so /usr/lib/lib3.so.0 /usr/lib/lib4.so /usr/lib/lib4.so.0 /usr/lib/lib5.a /usr/lib/lib5.a.0 /usr/include/include1.h /usr/include/include2.h /usr/include/include3.h /usr/include/include4.h));
    @{$self->{expectedcontent_sub}}=sort(qw(/usr/wibble2 /usr/bin/wibblewibble /usr/bin/hello.pl /usr/bin/subbin/hello.pl));
    @{$self->{expectedcontent_variant2}}=sort(qw(/usr/lib/lib1.so /usr/lib/lib1.so.0 /usr/lib/lib2.so /usr/lib/lib2.so.0 /usr/lib/lib3.a /usr/lib/lib3.a.0 /usr/lib/lib3.so /usr/lib/lib3.so.0 /usr/lib/lib4.so /usr/lib/lib4.so.0 /usr/lib/lib5.a /usr/lib/lib5.a.0));
    return $self;
}

sub tests
{
    return qw(test_buildPackage test_subPackage);
}
