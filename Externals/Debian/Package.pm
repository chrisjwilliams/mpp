# -----------------------------------------------
# Debian::Package
# -----------------------------------------------
# Description: 
# Manipulate Debian Packages
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new(filename[,workdir]) : new object
# control() : return an array containing the lines of the control file
#

package Debian::Package;
use strict;
use File::Temp qw/ tempdir /;
1;

# -- initialisation

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{file}=shift;
    $self->{workdir}=shift;
    if( ! defined $self->{workdir} 
          || $self->{workdir} eq "" ) {
        $self->{workdir} = tempdir();
    }
    return $self;
}

sub filename {
    my $self=shift;
    return $self->{file};
}

sub content {
    my $self=shift;
    if( ! defined $self->{contents} ) {
        my $cmd="dpkg-deb --contents ".$self->{file};
        my @contents=`$cmd`;
        foreach my $item ( @contents ) {
            my ($perm, $owner, $size, $date, $time, $file)=split( /\s+/, $item );
            $file=~s/^.//;
            if($file=~/(.*) -> (.*)/) {
                $file=$1;
            }
            push @{$self->{contents}}, $file;
        }
    }
    return @{$self->{contents}};
}

sub control {
    my $self=shift;
    #require Archive::Ar;
    #require Archive::Tar;
    #my $carchive=control.tar.gz
    #my $deb=Archive::Ar->new($self->{file});
    #%data=$deb->get_content($carchive)
    #my $tar=Archive::Tar->new($data{data});
    #$tar->read();
    #if($tar->contains_file( "DEBIAN/control" ) {
    #
    #   return split( /\n/, $tar->get_content("DEBIAN/control"));
    #}

    if( !defined $self->{control} )
    {
        my $cmd="dpkg-deb --control ".$self->{file}." ".$self->{workdir};
        die "$cmd : $?", if system($cmd);
        my $cfile=$self->{workdir}."/control";
        my $fh=FileHandle->new("<".$cfile);
        while( <$fh> ) {
            chomp;
            push @{$self->{control}}, $_;   
        }
    }
    return @{$self->{control}};
}

sub arch {
    my $self=shift;
    my $arch=shift;
    foreach my $line ( $self->control() ) {
        next, if $line!~/Architecture:\s*(.*)\s*/i;
        $arch=$1;
    }
    return $arch;
}
