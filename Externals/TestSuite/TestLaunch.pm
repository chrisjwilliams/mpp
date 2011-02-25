#
#  Perl test launcher
#
#

package TestSuite::TestLaunch;
use Cwd;
use FindBin;
use File::Path;
use IO::Handle;
use File::Spec;
use strict;
1;

sub new {
    my $class=shift;
    #my %hself : shared = ();
    #my $self = bless (\%hself, $class);
    my $self=bless( {}, $class );
    $self->{loc}=shift;
    $self->{fail}=0;
    $self->{pass}=0;
    $self->{run}=0;
    $self->{tmpdir}=File::Spec->tmpdir()."/testlauncher_test$$";
    $self->{testConfigDir}=shift || $FindBin::Bin."/TestConfig";
    #$self->{tests}=&share( {} );
    #$self->{testers}=&share( {} );
    mkdir $self->{tmpdir} or die( "unable to create temporary working dir : $!" );
    bless $self, $class;
    return $self;
}

sub usage {
    my $self=shift;
    print "Funtion: Run automated tests suites. All tests will be run unless otherwise specified\n";
    print "Usage: $0 [test_name, test_name]\n";
}

sub run {
    my $self=shift;
    while ( defined $_[0] && $_[0]=~/^-(.*)/ ) {
        my $arg=$1;
        shift @_;
        if( $arg eq "help" )
        {
            $self->usage();
        }
        else {    
            print "unknown option -$arg\n";
            exit 1;
        }
    }

    if( ! defined $_[0] )
    {
        # test everything
        my $avail=$self->listTests();
        if( defined $avail )
        {
            foreach my $t ( keys %{$avail} )
            {
                $self->runtest($t);
            }
        }
        else {
            print "No tests found\n";
        }
    }
    else {
        # --- test selection
        $self->runtest(@_);
    }
    print "Total tests run : ",$self->{run}, "\n", "Failed: ", $self->{fail}, "\n", "Passed: ", $self->{pass}, "\n";
    return $self->{fail};
}

sub listTests {
    my $self=shift;
    if( ! keys %{$self->{tests}} )
    {
        use DirHandle;
        my $dh=DirHandle->new($self->{loc}) or 
        die "unable to access $self->{loc} $!\n";
        my @files=grep !/^\.\.?$/, readdir($dh);
        undef $dh;
        foreach my $file ( @files ) {
            if ( -f $self->{loc}."/".$file ) {
                if( $file=~/(test_.*)\.pm$/ )
                {
                    $self->{tests}->{$1}=$file;
                }
            }
        }
    }
    return $self->{tests};
}

sub runtest {
    my $self=shift;
    my $test=shift;

    $self->listTests();
    if( exists $self->{tests}{$test} )
    {
        if( ! defined  $self->{testers}{$test} ) {
            require $self->{tests}{$test};
            my $tdir=$self->{tmpdir}."/".$test;
            mkdir $tdir or die ( "unable to create $tdir : $!\n");
            my $obj=$test->new( $self->{testConfigDir}, $tdir );
            $self->{testers}{$test}=$obj;
        }
        foreach my $t ( $self->{testers}{$test}->tests() )
        {
            $self->{run}++;
            $self->_runtest($self->{testers}{$test},$t, $test);
        }
    }
}

sub DESTROY {
    my $self=shift;
    # lock needed to work around buggy threads
    # where DESTROY is called for each forked copy
    return unless $self->{lock}==0; 
    #print "TestLaunch::DESTROY\n";
    rmtree( $self->{tmpdir} );
}

sub _runtest {
    my $self=shift;
    my $tester=shift;
    my $method=shift;
    my $test=shift;

    my $testid=$test."::".$method;
    STDOUT->autoflush(1);
    print "Running $testid ...................  ";
    eval {
        $self->{lock}=1;
        $tester->$method();
        $self->{lock}=0;
    };
    if ($@)
    {
        $self->{fail}++;
        print "FAIL\n\t$@\n";
    }
    else {
        $self->{pass}++;
        print "PASS\n";
    }
}
