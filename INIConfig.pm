# -----------------------------------------------
# INIConfig
# -----------------------------------------------
# Description: 
# Parse an INI format file
#
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new(): new object
# clone(section_reg_exp) : return a new object identical to this one, or containing only the sections matching the reg exp.
# merge(INIConfig) : merge the values of the given INIConfig into this object
# mergeSection( section_name, INIConfig) : merge the specified section form the given INICon
# sections([regex]) : return a list of defined sections
# section(section_name)  : return varaibles of a section as a hash
# var(section_name,var_name) : return the value of the specified variable
# vars(section_name) : return list of defined variables in the specified section
# list(section_name) : return the list associated with a section
# itemExists(section_name, item ) : return bool if the stated item exists in the list
# readFile(filename) : locad data from the specified ini file
# removeItemFromList(section_name, item) : remove an item from the specified list
# setVar(section_name,var_name, value) : set the variable
# setList(section_name, item) : insert the item into the appropriate list
# clearList(section_name) : clears all elements from a list
# clearSection(section_name) : remove entire section
# definedSection(section_name) : return 1 if the section is defined
# saveToFile(file) : Save any changes to the filename
# setDefaultFile(filename) : set the filename that will be saved to with save()

package INIConfig;
use strict;
use Carp;
1;

# -- initialisation

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{vars}={};
    @{$self->{sections}}=();
    foreach my $file ( @_ ) {
        if( defined $file  && -f $file ) {
            $self->readFile($file);
        }
    }
    return $self;
}

sub setDefaultFile {
    my $self=shift;
    $self->{defaultFile}=shift;
}

sub save {
    my $self=shift;
    croak("no default file set"), if( ! defined $self->{defaultFile});
    $self->saveToFile($self->{defaultFile});
}


sub clone {
    my $self=shift;
    my $pat=shift;
    my $clone=new INIConfig();
    if( ! defined $pat ) {
        $clone->merge($self);
    }
    else {
        foreach my $section ( $self->sections($pat) ) {
             $clone->mergeSection($section,$self);
        }
    }
    return $clone;
}

#
# crate a new INIConfig object with all sections that match
# the first pattern, as sections that are reduced by the second 
# pattern.
#
sub breakout {
    my $self=shift;
    my $pat=shift;
    my $reducer=shift;
    my $clone=new INIConfig();
    foreach my $section ( $self->sections($pat) ) {
         (my $reduced=$section)=~s/$reducer//;
         $clone->mergeSection($reduced,$self, $section);
    }
    return $clone;
}

sub definedSection {
    my $self=shift;
    my $name=shift;
    #return (( grep( /^$name$/, @{$self->{sections}} ) )?1:0);
    return (( grep( /^$name$/, $self->sections() ) )?1:0);
}

sub sections {
    my $self=shift;
    my $pat=shift;
    if( defined $pat ) {
        my @secs=();
        for(@{$self->{sections}}) {
            push(@secs,$_ ), if($_=~/$pat/);
        }
        return @secs;
    }
    else {
        return (@{$self->{sections}});
    }
}

sub section {
    my $self=shift;
    my $section=shift;
    return $self->{vars}{$section};
}

sub saveToFileHandle {
    my $self=shift;
    my $fh=shift;
    $self->_save($fh);
}

sub saveToFile {
    my $self=shift;
    my $file=shift;
    $self->_savefile($file);
}

sub var {
    my $self=shift;
    my $section=shift;
    my $name=shift;
    if( defined $self->{vars}{$section} ) {
        return $self->{vars}{$section}{$name};
    }
    return undef;
}

sub clearSection {
    my $self=shift;
    my $section=shift;

    $self->clearList($section);
    delete $self->{vars}{$section};
    my @tmp=();
    for(@{$self->{sections}}) {
        if($_ ne $section ) {
            push @tmp, $_;
        }
    }
    @{$self->{sections}}=@tmp;
}

sub clearList {
    my $self=shift;
    my $section=shift;

    delete $self->{listArray}{$section};
}

sub vars {
    my $self=shift;
    my $section=shift;
    return ( keys %{$self->{vars}{$section}} );
}

sub list {
    my $self=shift;
    my $section=shift;
    if( !defined $self->{listArray}{$section} )
    {
        my @empty = ();
        return @empty;
    }
    #    @{$self->{listArray}{$section}}=();
    #    foreach my $key ( keys %{$self->{lists}{$section}} )
    #    {
    #       if( $self->{lists}{$section} )
    #       {
    #           push @{$self->{listArray}{$section}},$key;
    #       }
    #   }
    return @{$self->{listArray}{$section}};
}

sub itemExists {
    my $self=shift;
    my $section=shift;
    my $item=shift;
    my $rv=0;
    if ( defined $section && defined $item ) {
        foreach my $i ( $self->list($section) ) {
            if ( $i eq $item ) {
                $rv=1; last;
            }
        }
    }
    return $rv;
}

sub removeItemFromList {
    my $self=shift;
    my $section=shift || return;
    my $item=shift || return;
    #delete $self->{lists}{$section}{$item};
    #delete $self->{listArray}{$section};

    if( defined $self->{listArray}{$section} ) {
        for(my $i=0; $i < scalar @{$self->{listArray}{$section}}; ++$i ) {
            if( $self->{listArray}{$section}[$i] eq $item ) {
                delete $self->{listArray}{$section}[$i];
            }
        } 
    }
}

sub removeVar {
    my $self=shift;
    my $section=shift;
    my $var=shift;
    my $val=shift;

    if( defined $self->{vars}{$section} )
    {
       if( defined $val && $val ne "" )
       {
            # only delete it if it matches
           if( $self->{vars}{$section}{$var} eq $val ) {
               delete $self->{vars}{$section}{$var};
           }
       }
       else {
           delete $self->{vars}{$section}{$var};
       }
    }
}

sub setVar {
    my $self=shift;
    my $section=shift;
    my $var=shift;
    my $val=shift;

    if( !defined $self->{vars}{$section} )
    {
        push (@{$self->{sections}}, $section),
                if( ! grep /^\Q$section\E/, @{$self->{sections}} );
    }
    $self->{vars}{$section}{$var}=$val;
}

sub setList {
    my $self=shift;
    my $section=shift;

    if( !defined $self->{listArray}{$section} )
    {
        push (@{$self->{sections}}, $section),
                if( ! grep /^$section/, @{$self->{sections}} );
    }
    foreach my $line ( @_ ) {
        if ( $line=~/\s*\!(\S+)\s*/ )
        {
        #    $self->{lists}{$section}{$1}=0;
             push @{$self->{listArray}{$section}}, $1;
        }
        else {
             push @{$self->{listArray}{$section}}, $line;
        #    $self->{lists}{$section}{$line}=1;
        }
    }
}

sub merge {
    my $self=shift;
    my $config=shift;

    foreach my $section ( $config->sections() )
    {
        $self->mergeSection($section, $config);
    }
}

sub mergeSection {
    my $self=shift;
    my $section=shift;
    my $config=shift;
    my $section2=(shift||$section); # default merges same name sections

    foreach my $item ( $config->list($section2) ) {
        $self->setList($section,$item);
    }
    foreach my $var ( $config->vars($section2) ) {
        $self->setVar($section,$var, $config->var($section2,$var) );
    }
    push (@{$self->{sections}}, $section),
                if( ! grep /^$section/, @{$self->{sections}} );
}

# -- private methods -------------------------

sub _savefile {
    my $self=shift;
    my $file=shift;
    use FileHandle;
    my $fh=FileHandle->new();
    $fh->open(">".$file) or croak "problem opening $file $!";
    $self->_save($fh);
}

sub _save {
    my $self=shift;
    my $fh=shift;
    foreach my $section ( $self->sections() ) {
        $self->saveSection($section, $fh);
    }
}

sub saveSection {
    my $self=shift;
    my $section = shift;
    my $fh = shift;

    print $fh "[$section]\n";
    foreach my $var ( $self->vars($section) ) {
        print $fh $var,"=\"",$self->var($section,$var),"\"\n";
    }
    foreach my $item ( $self->list($section) ) {
        print $fh $item,"\n";
    }
    print $fh "\n";
}

sub readFile {
    my $self=shift;
    my $file=shift;

    my $section="none";
    use FileHandle;
    my $fh=FileHandle->new();
    $fh->open("<".$file) or croak "problem opening $file $!";
    while ( <$fh> ) {
        chomp;
        my $line=$_;
        next, if $line=~/^\s*#.*/; # -- skip comments
        # - section header
        if ( $line=~/^\s*\[(.+)\]\s*$/ ) {
            $section=$1;
            if( ! $self->definedSection( qr/\Q$section\E/ ) ) {
                push @{$self->{sections}}, $section;
            }
            next;
        }
        # - simple variable setting
        if ( $line=~/(.+?)\s*=\s*(.+)\s*$/o ) {
            my $var=$1;
            my $val=$2;
            if ( $val=~/^\s*"(.+)\"\s*$/o ) {
                $val=$1;
            }
            $self->{vars}{$section}{$var}=$val;
        #print "Setting [$section] $var = $val\n";
        }
        elsif ( $line=~/^\s*clear\s*$/ ) {
            # clear the section of all vars
            delete $self->{vars}{$section};
        }
        # simple lists and list exclusions
        elsif ( $line=~/\s*\!?(\S+)\s*/ )
        {
            $self->setList($section, $line);
            #    $self->{lists}{$section}{$1}=0;
        }
        #elsif ( $line=~/\s*(\S+)\s*/ )
        #{
        #    $self->{lists}{$section}{$1}=1;
        #}
    }
}
