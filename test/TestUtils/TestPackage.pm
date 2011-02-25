# -----------------------------------------------
# TestUtils::TestPackage
# -----------------------------------------------
# Description:
#    Provide easy access to packages
#
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new( configurationDirectory )    : new object
#
#

package TestUtils::TestPackage;
use strict;
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self={};
    $self->{testConfigDir}=shift;
    #print "Test Config: ",$self->{testConfigDir},"\n";
    $self->{tmpdir}=shift;
    $self->{loc}=$self->{testConfigDir}."/test_project";
    bless $self, $class;

    return $self;
}

sub name {
    my $self=shift;
    my $type=shift;
    return $self->{names}{$type};
}

sub getPackage {
    my $self=shift;
    my $type=shift;

    if( defined $type )
    {
        require DirHandle;
        my $dir=$self->{testConfigDir}."/Packages";
        my $dh=DirHandle->new($dir);
        my @files=$dh->read();
        my $pkg=shift;
        while ( defined ($pkg=(shift @files)) ) {
            if( $pkg=~/(.+)\.$type$/ ) {
                $self->{names}{$type}=$1;
                return $dir."/".$pkg;
            }
        }
        #my $pkg=$dir."/testProject.$type";
        #if( -f $pkg ) {
        #   return $pkg; 
        #}
    }
    die("unable to find a test package of type $type");
    #my $class="Packagers::".$type;
    #eval require $class;
    #if( $@ )
    #{
    #   die("unknown package type '".$type."' $@");
    #}
    #my $packager=$class->new($self->{host}, "", $self->{config});
    #$packager->build($testproject);
    #my $pkgname;
    #return $pkgname;
}

sub srcFiles {
    my $self=shift;
    my $dir=$self->{loc}."/src";
    my $dh=DirHandle->new($dir) or die ("unable to read $dir :".$!);
    my @files=readdir($dh);
    my @list;
    foreach my $file ( @files ) 
    {
        if( -f $dir."/".$file )
        {
            push @list, "src/".$file;
        }
    }
    return @list;
}

sub tar {
    require Cwd;
    my $self=shift;

    require Archive::Tar;
    $self->{tar}=$self->{tmpdir}."/testproject_src.tar";
    my $tar=Archive::Tar->new();
    print $self->{testConfigDir}."/test_project","\n";
    my $dir=Cwd::cwd();
    chdir $self->{testConfigDir}."/test_project";
    $tar->setcwd($self->{testConfigDir}."/test_project") or die $!;
    $tar->add_files($self->srcFiles());
    $tar->write($self->{tar})
        or die "unable to open tar file $self->{tar}:$!";
    chdir $dir;

    return $self->{tar};
}

sub arch {
    my $self=shift;
    return "x86_64";
}

sub setupTestProject {
    require INIConfig;
    require ProjectInfo;
    my $self=shift;
    my $config=INIConfig->new($self->{testConfigDir}."/test_project/install.ini");
    my $pinfo=ProjectInfo->new($config, "testProject", "testVersion"  );
    # -- set up the src tree on the host
    my $work=$self->{localhost}->workDir()."/testProject";
    my $src=$work."/src";
    File::Copy::Recursive::dircopy( $self->{testConfigDir}."/test_project/src", $src );
    my $log=FileHandle->new(">".$self->{tmpdir}."/build_log");
    #my $log=*STDOUT;

    return ( $src, $work, $config , $pinfo, $log);
}
# -- private methods -------------------------
sub _buildTestRpm {
    my $self=shift;
    my ( $src, $work, $config , $pinfo, $log ) = $self->setupTestProject();
    my $pack=Packagers::Rpm->new($self->{localhost}, "testProject",$config, $pinfo);
    $pack->build($self->{tmpdir}, $log);
    return $pack->packageNames();
}
