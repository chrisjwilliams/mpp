# ----------------------------------------
#
# Unit test for the RemoteFileHandle Class
#
# ----------------------------------------
#


package test_RemoteFileHandle;
use RemoteFileHandle;
use TestUtils::MppApi;
use File::Temp qw( tempfile );
use File::Sync qw( fsync );
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self,$class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{api}=TestUtils::MppApi->new($self->{testConfigDir}, $self->{tmpdir});
    $self->{platformM}=$self->{api}->getPlatformManager();
    $self->{localhost}=$self->{platformM}->getPlatform("localhost");
    die( "Error initilising localhost platform" ), if ! defined $self->{localhost};
    return $self;
}

sub tests
{
    return qw(test_writeFile test_badMode);
}

sub test_badMode {
    my $self=shift;

    # generate the test file
    my $fh=RemoteFileHandle->new($self->{localhost});
    eval {
        $fh->open("testfile");
    };
    if($@) {
        return 0;
    }
    else {
        die( "expecting unsupported mode error" );
    }
}

sub test_readFile {
    my $self=shift;
    my $txt="wibble.....jkdlfsdjkla\n";
    my ($tempfh, $fname) = tempfile( UNLINK => 1 );
    print $tempfh $txt;
    $tempfh->close();
    $tempfh->flush();
    $tempfh->sync() or die "sync : $!";
    print "tempfile=$fname\n";

    my $fh=RemoteFileHandle->new($self->{localhost}, $self->{tmpdir} );
    die("unable to create tmp file"), if ! -f $fname;
    $fh->open("<".$fname) or die("unable to open file $fname: $!\n");
    if( <$fh> ne $txt ) {
        die("unexpected file content");
    }
    $fh->close();
}

sub test_writeFile {
    my $self=shift;

    # generate the test file
    my $text="Hello\n";
    my $fh=RemoteFileHandle->new($self->{localhost});
    $fh->open(">mytest/testfile");
    print $fh $text;
    $fh->close();

    # check the file exists where we expect it
    my $expect=$self->{localhost}->workDir()."/mytest/testfile";
    if( ! -f $expect )
    {
        die( "File $expect does not exist" );
    }
}
