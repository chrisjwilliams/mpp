# ----------------------------------
# class FileExpander
# Description:
#   Copy an input file to the destination expanding
#   variables on the way
#
#-----------------------------------
# Methods:
# new(file, Environment) :
# copy(FileHandle) : copy file to the given filehandle, expanding any set variables on the way
#-----------------------------------


package FileExpander;
use FileHandle;
use Environment;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    my $file=shift;
    $self->{file}=$file;
    $self->{env}=shift;
    #for(keys %{$self->{env}}){
    #    print "env $_= ",$self->{env}{$_},"\n";
    #}
    die("file  not defined"), if( ! defined $file );
    die("file ".$file." does not exist"), if( ! -f $file );
    return $self;
}

sub setEnv {
    my $self=shift;
    my $var=shift;
    $self->{env}{$var}=shift;
}

sub expandVars {
    my $self=shift;
    my $string=shift;
    return $self->{env}->expandString($string);
#    if( defined $string ) {
#        foreach my $v ( keys %{$self->{env}} ) {
#            $string=~s/(.*?)(?<!\$)\$\{$v\}(.*?)/$1$self->{env}{$v}$2/g;
#        }
#    }
#    return $string;
}

sub copy {
    my $self=shift;
    my $fh=shift;

    my $in=FileHandle->new("<".($self->{file})) or die("unable to open ".($self->{file})." : $!");
    while(<$in>) {
        print $fh $self->expandVars($_);
    }
    $in->close();
}
