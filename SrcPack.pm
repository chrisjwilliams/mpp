# ----------------------------------
# class SrcPack
# Description:
#   Maintain a source package
#-----------------------------------
# Methods:
# new(package) :
# packageFile() : return the packageFile
# patch(@patches) : apply the patches tp the src
#-----------------------------------

package SrcPack;
use strict;
use File::Basename;
use File::Path;
use File::Spec;
use Config;
use threads;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{config}=shift;
    die("srcDirectory not defined"), if ( ! defined $self->{config}{srcDirectory} );
    $self->{rawpack}=$self->{config}{srcPack};
    $self->{srcpack}=$self->{rawpack};
    if( -d $self->{rawpack} ) {
        # -- default package type
        $self->{type}="tbz";
        $self->{needspack}=1;
    }
    else {
        $self->{needspack}=0;
        $self->{type}=$self->type();
    }
    my $tid="";
    if ($Config{useithreads}) {
        $tid = "t".threads->tid();
    }
    $self->{tmp}=File::Spec->tmpdir()."/SrcPack".$$.$tid.$self->{rawpack};
    mkpath $self->{tmp} or die ("unable to create $self->{tmp}: $!");
    return $self;
}

sub DESTROY {
    my $self=shift;
    if( defined $self->{tmp} && -d $self->{tmp} ) {
        rmtree( $self->{tmp} );
    }
}

sub srcDirectory {
    my $self=shift;
    return $self->{config}{srcDirectory};
}

sub patch {
    my $self=shift;
    my @patches=@_;

    my $dir=$self->_unpack($self->{tmp}, $self->rawPackage());
    for(@patches) {
        if(defined $_ && -f $_ ) {
            $self->_applyPatch($dir,$_);
        }
        else {
            die("unknown patch '$_'");
        }
    }
    $self->{needspack}=1;
}

sub rawPackage {
    my $self=shift;
    return $self->{rawpack};
}

sub packageFile {
    my $self=shift;
    if( $self->{needspack} || -d $self->{srcpack} ) {
        $self->_repack($self->{tmp});
    }
    return $self->{srcpack};
}

sub type {
    my $self=shift;
    if( ! defined $self->{type} ) {
        if( -d $self->{srcpack} ) {
            # -- default package type
            $self->{type}="tbz";
        }
        else {
            my $pack=basename($self->{srcpack});
            ($self->{type}=$pack)=~s/.+?\.(.*)$/$1/;
        }
    }
    return $self->{type};
}

# -- private methods -------------------------
sub _applyPatch {
    my $self=shift;
    my $top=shift;
    my $patchfile=shift;

    print "applying patch $patchfile\n";
    $self->_invoke("cd $top; patch -p0 <$patchfile");
}

sub _unpack {
    my $self=shift;
    my $workspace=shift;
    my $file = shift;
    if( $self->{unpacked}{$file} ) {
        return $self->{unpacked}{$file};
    }
    my($filename, $directories, $suffix) = fileparse($file, '\..*');
    my $cmd="";
    if( $suffix =~ /zip/i ) {
        $cmd="unzip";
    }
    elsif( $file =~ /tar\.gz$/i || $suffix=~/tgz$/i )
    {
        $cmd="tar -xzf";
    }
    elsif( $file =~ /tar\.bz2$/i || $suffix=~/tbz$/i ) {
        $cmd="tar -xjf";
    }
    elsif( $suffix =~ /tar$/i )
    {
        $cmd="tar -xf";
    }
    if( $cmd ne "" ) {
        print "unpacking file with $cmd in $workspace\n";
        $self->_invoke("cd $workspace; $cmd $file;");
    }
    else {
        die ("Unknown file type ( $suffix )");
    }
    $self->{unpacked}{$file}=$workspace."/".$self->{config}{srcDirectory};
    return $self->{unpacked}{$file};
}

sub _repack {
    my $self=shift;
    my $dir=shift;
    my $file=basename($self->{rawpack});

    my $type=shift;
    my $cmd="";
    if( ! defined $type ) {
        $type=$self->type();
    }
    if( $type =~ /zip/i ) {
        $cmd="zip";
    }
    elsif( $type =~ /tar.gz$/i || $type=~/tgz$/i )
    {
        $cmd="tar -czf";
    }
    elsif( $type =~ /tar.bz2$/i || $type=~/tbz$/i ) {
        $cmd="tar -cjf";
    }
    elsif( $type =~ /tar$/i )
    {
        $cmd="tar -cf";
    }
    if( $cmd ne "" ) {
        print "packing file with $cmd $file $dir\n";
        $self->_invoke( "cd $dir;".$cmd." ".$file." ".$self->srcDirectory() );
    }
    else {
        die ("Unknown file type ( $type )");
    }
    $self->{srcpack}=$dir."/".$file;
    return $dir."/".$file;
}

sub _invoke {
    my $self=shift;
    print "invoking @_\n";
    ( system(@_) == 0 )  or die "unable to execute @_";
}
