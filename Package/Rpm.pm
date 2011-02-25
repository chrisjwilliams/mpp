# ----------------------------------
# class Package::Rpm
# Description:
#   Access Header information from an RPM header
#-----------------------------------
# Methods:
# new() :
#-----------------------------------
#use RPM::Header;

package Package::Rpm;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{file}=shift;
    warn ( "file '".($self->{file})."' does not exist" ), if ( ! -f $self->{file} );
    #$self->{head}= new RPM::Header( $self->{file} ) or die "$RPM::err";

    # --- analyse the filename to extract basic info as Rpm::Header is broken
    (my $file=$self->{file})=~s/.+[\\\/](.+)/$1/;
    die "unable to determine info from filename", if( $file!~m/(.+?)-(.+?)-(.+?)\.(.+)\.rpm$/ );
    $self->{name}=$1;
    $self->{version}=$2;
    $self->{revision}=$3;
    #print "name=", $self->{name}, " version=", $self->{version}, "\n";
    #print "revision=", $self->{revision}, " arch=", $self->{arch}, "\n";

    bless $self, $class;
    return $self;
}

sub name {
    my $self=shift;
    return $self->{name};
    #return $self->{head}{name};
}

sub file {
    my $self=shift;
    return $self->{file};
}

sub arch {
    my $self=shift;
    if( ! defined $self->{arch} ) {
        my $cmd="rpm -qp --qf \"%{arch}\" ".$self->{file};
        $self->{arch}=`$cmd`;
    }
    return $self->{arch};
}

sub content {
    my $self=shift;
    if( ! defined $self->{contents} ) {
        my $cmd="rpm -qlp ".$self->{file};
        my @contents=`$cmd`;
        foreach my $item ( @contents ) {
            chomp $item;
            push @{$self->{contents}}, $item;
        }
    }
    return @{$self->{contents}};
}


sub version {
    my $self=shift;
    return $self->{version};
}

sub _dump {
    my $self=shift;

    foreach my $key (sort keys %{$self->{head}} )
    {
        print $key,"\n";
    }
}
