# ----------------------------------
# class test_ContentList
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_ContentList;
use strict;
use ContentList;
use TestUtils::MppApi;
use INIConfig;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    $self->{api}=TestUtils::MppApi->new( $self->{testConfigDir}, $self->{tmpdir} );
    $self->{platformM}=$self->{api}->getPlatformManager();
    $self->{localhost}=$self->{platformM}->getPlatform("localhost");

    # -- set up a generic ini file
    my @fileinc=qw(a.h b.h);
    $self->{config}=new INIConfig();
    $self->{config}->setList("install",qw(/usr/wibble/* /usr/wibblefile));
    $self->{config}->setList("install::include",@fileinc);
    $self->{config}->setVar("install::include","c.h", "someother_c.h");
    $self->{config}->setVar("install::include","d.h", "someother_d.h");
    $self->{config}->setVar("install_link::include::linkdir","link_to.h","target.h");

    return $self;
}

sub tests {
    return qw( test_getdir test_noPlatform test_platform test_link test_remove test_dirs);
}

sub test_dirs {
    my $self=shift;
    my $content=ContentList->new( $self->{config}, undef );
    my @dirs=sort($content->dirs());
    my @expect=sort(qw( ${install::include} ${install::include}/linkdir /usr /usr/wibble));
    die "expecting ".($#expect+1)." dirs, got ".($#dirs+1)." (@dirs)", if ($#dirs ne $#expect);
    my $i=-1;
    while( ++$i < $#dirs ) {
        die( "expecting @expect, got @dirs"), if ( $dirs[$i] ne $expect[$i]);
    }
}

sub test_getdir {
    my $self=shift;
    my $content=ContentList->new( $self->{config}, undef );
    my $dir1=$content->_getdestdir("install::include::fred");
    my $edir1="\${install::include}/fred";
    die("unexpected directory : $dir1, expecting $edir1") , if ( $dir1 ne $edir1 );
    my $dir2=$content->_getdestdir("install");
    my $edir2="";
    die("unexpected directory : $dir2, expecting \'$edir2\'") , if ( $dir2 ne $edir2 );
}

sub test_noPlatform {
    my $self=shift;
    my $content=ContentList->new( $self->{config}, undef );
    my @files=$content->files();
    die "expecting 6 files, got ".($#files+1)." (@files)", if ($#files ne 5 );
    my $found={};
    foreach my $f ( @files ) {
        die "returned 2 copies of $f", if ( defined $found->{$f} );
        if( $f->[0] eq "c.h" ) {
            die "expecting someother_c.h got ".($f->[1]), if ( $f->[1] ne "\${install::include}/someother_c.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "d.h" ) {
            die "expecting someother_d.h got ".($f->[1]), if ( $f->[1] ne "\${install::include}/someother_d.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "a.h" ) {
            die "expecting a.h got $f->[1]",  if ( $f->[1] ne "\${install::include}/a.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "b.h" ) {
            die "expecting b.h got $f->[1]",  if ( $f->[1] ne "\${install::include}/b.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "\${prefix}/usr/wibble/*" ) {
            die "expecting /usr/wibble got ".($f->[1]), if ( $f->[1] ne "/usr/wibble");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "\${prefix}/usr/wibblefile" ) {
            die "expecting /usr/wibblefile got ".($f->[1]), if ( $f->[1] ne "/usr/wibblefile");
            $found->{$f}=1;
            next;
        }
        die "unexpected value returned ($f->[0])";
    }
}

sub test_platform {
    my $self=shift;
    my $content=ContentList->new( $self->{config}, $self->{localhost});
    my @files=$content->files();
    die "expecting 6 files, got ".($#files+1)." (@files)", if ($#files ne 5 );
    my $found={};
    foreach my $f ( @files ) {
        die "returned 2 copies of $f", if ( defined $found->{$f} );
        if( $f->[0] eq "c.h" ) {
            die "expecting someother_c.h got ".($f->[1]), if ( $f->[1] ne "/usr/include/someother_c.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "d.h" ) {
            die "expecting someother_d.h got ".($f->[1]), if ( $f->[1] ne "/usr/include/someother_d.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "a.h" ) {
            die "expecting a.h got $f->[1]",  if ( $f->[1] ne "/usr/include/a.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "b.h" ) {
            die "expecting b.h got $f->[1]",  if ( $f->[1] ne "/usr/include/b.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "\${prefix}/usr/wibble/*" ) {
            die "expecting /usr/wibble got ".($f->[1]), if ( $f->[1] ne "/usr/wibble");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "\${prefix}/usr/wibblefile" ) {
            die "expecting /usr/wibblefile got ".($f->[1]), if ( $f->[1] ne "/usr/wibblefile");
            $found->{$f}=1;
            next;
        }
        die "unexpected value returned ($f->[0])";
        if( $f->[0] eq "\${prefix}/usr/wibble/*" ) {
            die "expecting /usr/wibble got ".($f->[1]), if ( $f->[1] ne "/usr/wibble");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "\${prefix}/usr/wibblefile" ) {
            die "expecting /usr/wibblefile got ".($f->[1]), if ( $f->[1] ne "/usr/wibblefile");
            $found->{$f}=1;
            next;
        }
    }

}

sub test_link {
    my $self=shift;
    my $content=ContentList->new( $self->{config}, $self->{localhost});
    my @files=$content->links();
    die "expecting 1 link, got ".($#files+1)." (@files)", if ($#files ne 0 );
    foreach my $f ( @files ) {
        if( $f->[0] eq "target.h" ) {
            die "expecting /usr/include/linkdir/link_to.h got ".($f->[1]), if ( $f->[1] ne "/usr/include/linkdir/link_to.h");
            next;
        }
        die "unexpected value returned ($f->[0])";
    }
}

sub test_remove {
    my $self=shift;
    my $content=ContentList->new( $self->{config}, $self->{localhost});

    # other has both a list item and a var item duplicates
    # it is the destination that is important, duplicates
    # with the same source but different destinations should
    # not be removed
    my @fileinc=qw(a.h c.h);
    my $otherConfig=INIConfig->new();
    $otherConfig->setList("install::include",@fileinc);
    $otherConfig->setVar("install::include","d.h","someotherdifferent_d.h");
    my $other=ContentList->new( $otherConfig, undef);

    $content->remove($other);

    my @files=$content->files();
    die "expecting 5 files, got ".($#files+1)." (@files)", if ($#files ne 4 );
    my $found={};
    foreach my $f ( @files ) {
        die "returned 2 copies of $f", if ( defined $found->{$f} );
        if( $f->[0] eq "c.h" ) {
            die "expecting someother_c.h got ".($f->[1]), if ( $f->[1] ne "/usr/include/someother_c.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "d.h" ) {
            die "expecting someother_d.h got ".($f->[1]), if ( $f->[1] ne "/usr/include/someother_d.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "b.h" ) {
            die "expecting b.h got $f->[1]",  if ( $f->[1] ne "/usr/include/b.h");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "\${prefix}/usr/wibble/*" ) {
            die "expecting /usr/wibble got ".($f->[1]), if ( $f->[1] ne "/usr/wibble");
            $found->{$f}=1;
            next;
        }
        if( $f->[0] eq "\${prefix}/usr/wibblefile" ) {
            die "expecting /usr/wibblefile got ".($f->[1]), if ( $f->[1] ne "/usr/wibblefile");
            $found->{$f}=1;
            next;
        }
        die "unexpected value returned ($f->[0])";
    }
}
