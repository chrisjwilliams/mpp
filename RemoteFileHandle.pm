# -----------------------------------------------
# RemoteFileHandle
# -----------------------------------------------
# Description:
# Create a file with the usual print fh syntax on a
# remote machine as if creating it locally
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new( platform )    : new object
#
#

package RemoteFileHandle;
use strict;
use IO::File;
use File::Basename;
use File::Spec;
our @ISA = qw(IO::File);
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self=$class->SUPER::new();
    bless $self, $class;
    ${*$self}{'remoteFileHandle_platform'}=shift;
    ${*$self}{'remoteFileHandle_workdir'}=shift;
    if( ! defined ${*$self}{'remoteFileHandle_workdir'} )
    {
        ${*$self}{'remoteFileHandle_workdir'}=File::Spec->tmpdir();
    }

    return $self;
}

sub setLogger {
    my $self=shift;
    my $log=shift;
    die "Attempt to set a ".(ref($log))." object as a logger", if( ref($log) ne "GLOB" );
    $self->{logger}=$log;
}

sub open {
    my $glob=shift;
    my $file=shift;

    if( $file=~/^>(.*)/ )
    {
        ${*$glob}{remoteFileHandle_file}=$1;
        my $tmpfile=${*$glob}{remoteFileHandle_tmpfile};
        if( defined $tmpfile && -f $tmpfile ) {
            $glob->close();
        }
        ${*$glob}{remoteFileHandle_tmpfile}=$glob->_newfilename();
        #print "attempting to open ${*$glob}->{remoteFileHandle_tmpfile}\n";;
        return $glob->SUPER::open(">".${*$glob}{remoteFileHandle_tmpfile});
        if( defined ${*$glob}{remoteFileHandle_perm} ) { chmod ${*$glob}{remoteFileHandle_perm}, ${*$glob}{remoteFileHandle_tmpfile} };
    }
    elsif( $file=~/^<(.*)/ )
    {
        my $f=$1;
        my ($localfile)=${*$glob}{remoteFileHandle_platform}->download( dirname($f),
                                ${*$glob}{remoteFileHandle_workdir}, basename($f) );
        return $glob->SUPER::open("<".$localfile);
    }
    else {
        die( "unsupported mode" );
    }
}

sub close {
    my $glob=shift;
    my $self=${*$glob};

    my $rv=$glob->SUPER::close();
    if( -f ${*$glob}{remoteFileHandle_tmpfile} ) {
        eval {
            ${*$glob}{remoteFileHandle_platform}->copyFile( ${*$glob}{remoteFileHandle_tmpfile}, ${*$glob}{remoteFileHandle_file}, $self->{logger} )
        };
        if($@) {
            unlink ${*$glob}{remoteFileHandle_tmpfile};
            die( "unable to create file on remote server:", ${*$glob}{remoteFileHandle_file}, $@);
        }
        unlink ${*$glob}{remoteFileHandle_tmpfile};
    }
    return $rv;
}

sub setPermissions {
    my $glob=shift;
    ${*$glob}{remoteFileHandle_perm}=shift;
    if( defined ${*$glob}{remoteFileHandle_tmpfile} ) {
        chmod ${*$glob}{remoteFileHandle_perm}, ${*$glob}{remoteFileHandle_tmpfile}
    }
}


# -- private methods -------------------------

sub _newfilename {
    my $self=shift;
    my $dir="/tmp";
    my $fname;
    do
    {
        $fname=$dir."/mpp_".$$.(int(rand(900000)));
    } while( -f $fname );
    return $fname;
}
