# ----------------------------------
# class ContentList
# Description:
#   An object to maintaing an accessible representation
#   of a packages contents
#-----------------------------------
# Methods:
# new(INIConfig, Platform) : a new object with data tailored for the given Platform
# files( $locationhash ) : return a list of 2 element arrays, [0]=source file [1]=destination location
# links( $locationhash ) : same as files() but for links
# remove( ContentList )  : remove from this content hash any duplicates found in the passed argument
#-----------------------------------

package ContentList;
use strict;
use File::Basename;
use File::Spec;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{config}=(shift->clone());
    $self->{platform}=shift;
    $self->{locations}=$self->{platform}->locations(), if( defined $self->{platform} ); 
    bless $self, $class;
    return $self;
}

sub dirType {
    my $self=shift;
    my $type=shift;
    if( ! defined $self->{dirstype}{$type} ) {
        my $dirs={};
        foreach my $sec ( $self->{config}->sections("install_?.*::$type" ) ) {
            my $d=$self->_getdestdir($sec);
            $dirs->{$d}=1;
        }
        @{$self->{dirstype}{$type}}=sort( keys %{$dirs} );;
    }
    return @{$self->{dirstype}{$type}};
}

sub dirs {
    my $self=shift;
    if( ! defined $self->{dirs} ) {
        my $dirs={};
        foreach my $sec ( $self->{config}->sections("install_?.*::" ) ) {
            my $d=$self->_getdestdir($sec);
            $dirs->{$d}=1;
        }
        foreach my $var ( $self->{config}->list("install") ) {
            next, if( $var!~/^[\\\/]/ );
            next, if( $var!~/(.*)\/\*/ );
            $dirs->{$1}=1;
        }
        foreach my $path ( keys %{$dirs} ) {
            while( ($path=dirname($path))=~/^[\\\/].+/ ) {
                $dirs->{$path}=1;
            }
        }
        @{$self->{dirs}}=sort( keys %{$dirs} );
    }
    return @{$self->{dirs}};
}
#
# return a list of 2 element arrays, [0]=source [1]=destination [2]=install type
#
sub files {
    my $self=shift;
    if( ! defined $self->{files} ) {
        my @files=();
        foreach my $sec ( $self->{config}->sections('install(:|$)') ) {
            (my $type=$sec)=~s/(.*?)::(.*)/$2/;
            my $dst=$self->_getdestdir($sec);
            foreach my $file ( $self->{config}->list($sec) ) {
                my @tmp;
                # -- special rules for simple install tag
                my $dest=($dst eq "")?dirname($file):$dst;
                $file='${prefix}'.$file, if( $file=~/^[\\\/]/ || $file=~/^\${install::/ );
                push @tmp,$file;
                if( $file=~/\*/ || $dest=~/\/$/ ) { 
                    # wild card requires a directory target
                    push @tmp,$dest, $type;
                }
                else {
                    push @tmp,$dest."/".(basename($file)), $type;
                }
                push @files, [@tmp];
            }
            foreach my $file ( $self->{config}->vars($sec) ) {
                my @tmp;
                push @tmp,$file;
                push @tmp,$dst."/".($self->{config}->var($sec, $file)), $type;
                push @files, [@tmp];
            }
        }
        @{$self->{files}}=@files;
    }
    return @{$self->{files}};
}

sub links {
    my $self=shift;

    my @files=();
    foreach my $sec ( $self->{config}->sections("install_link::.*" ) ) {
        (my $type=$sec)=~s/(.*?)::(.*)/$2/;
        my $dst=$self->_getdestdir($sec);
        foreach my $file ( $self->{config}->vars($sec) ) {
           my @tmp;
           $file='${prefix}'.$file, if( $file=~/^[\\\/]/ );
           push @tmp, ($self->{config}->var($sec, $file));
           push @tmp, $dst."/".$file, $type;
           push @files, [@tmp];
        }
    }
    return @files;
}

sub remove {
    my $self=shift;
    my $content=shift;

    foreach my $sec ( $content->{config}->sections() ) {
        for( $content->{config}->vars($sec) ) {
            if( defined $self->{config}->var($sec,$_) && 
                $self->{config}->var($sec,$_) eq $content->{config}->var($sec,$_) ) 
            {
                $self->{config}->setVar($sec,$_, undef);
            }
        }
        my @newlist=();
        my @other=$content->{config}->list($sec);
        foreach my $item ( $self->{config}->list($sec) ) {
            if( ! grep(/^$item$/, @other ) ) {
                push @newlist,$item;
            }
        }
        $self->{config}->clearList($sec);
        $self->{config}->setList($sec,@newlist);
    }
}

sub _getdestdir {
    my $self=shift;
    my $section=shift;
    if( $section ne "install" ) {
        (my $type=$section)=~s/^install.*?:://;
        my @types=split ( /::/, $type );
        my $dst=$types[0];
        my $dir=((defined $types[1])?$types[1]:"");
        $dir=~s/^(.+)/\/$1/; # insert a seperator
        my $fdst;
        if ( defined $self->{locations} ) { 
            $fdst=$self->{locations}{$dst};
        }    
        if( ! defined $fdst ) { # if not found make it a variable ref
            $fdst="\${install::$dst}";
        }
        $fdst.=$dir;
        return $fdst;
    }
    return "";
}


