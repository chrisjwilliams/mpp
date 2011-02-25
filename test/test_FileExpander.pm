# ----------------------------------
# class test_FileExpander
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_FileExpander;
use strict;
use FileHandle;
use FileExpander;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;

    $self->{file}=$self->{tmpdir}."/original";
    my $fh=FileHandle->new(">".$self->{file}) or die ("unable to create file ".$self->{file}." : $!");
    print $fh '${variable1}${variable2} $${variable2}';
    $fh->close();
    $self->{envh}{variable1}="testvar1";
    $self->{envh}{variable2}="testvar2";
    $self->{env}=Environment->new($self->{envh});
    return $self;
}

sub tests {
    return qw( test_expansion );
}

sub test_expansion {
    my $self=shift;

    my $file=$self->{tmpdir}."/testout";
    my $fh=FileHandle->new(">".$file) or die ("unable to create file ".$file." : $!");
    my $fe=FileExpander->new($self->{file}, $self->{env} );
    $fe->copy($fh);
    $fh->close();
    my $fin=FileHandle->new("<".$file) or die ("unable to read file ".$file." : $!");
    my $txt=<$fin>;
    my $expect='testvar1testvar2 $${variable2}';
    die("expecting '$expect', got '$txt'"), if( $txt ne $expect );
}

