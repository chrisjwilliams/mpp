# ----------------------------------
# class test_SysProcedureFile
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_SysProcedureFile;
use SysProcedure::File;
use TestUtils::MppApi;
use strict;
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
    return $self;
}

sub tests {
    return qw( test_empty test_noroot test_root test_cat);
}

sub test_empty {
    my $self=shift;
    my $d=$self->{localhost}->workDir()."/empty";
    my $fi = SysProcedure::File->new($self->{localhost},$d);
    $fi->execute();
    die( "$d file does not exist" ), if ( ! -f $d );
}

sub test_noroot {
    my $self=shift;
    my $file=$self->{localhost}->workDir()."/unrooted";
    my $fi = SysProcedure::File->new($self->{localhost},$file);
    $fi->add(qw(a b c d));
    $fi->execute();
    die( "$file file does not exist" ), if ( ! -f $file );
}

sub test_root {
    my $self=shift;
    my $mfile=$self->{localhost}->workDir()."/rooted";
    my $fi = SysProcedure::File->new($self->{localhost},$mfile);
    $fi->add(qw(a b c d));
    my $root=$self->{localhost}->workDir();
    my $file=$root.$mfile;
    $fi->execute($root);
    die( "$file file does not exist" ), if ( ! -f $file );
}

sub test_cat {
    my $self=shift;
    my $cfile=$FindBin::Bin."/test.pl";
    my $file=$self->{localhost}->workDir()."/catted";
    my $fi = SysProcedure::File->new($self->{localhost},$file);
    $fi->add(qw/vvvvvv vvvvvvv vvvv/, "\n");
    $fi->cat(PlatformFile->new($cfile, undef ));
    $fi->cat(PlatformFile->new($cfile, $self->{localhost} ));
    $fi->add(qw/^^^ ^^^^^ ^^^^^^^^^/, "\n");
    $fi->execute();
    die( "$file file does not exist" ), if ( ! -f $file );
}
