# ----------------------------------
# class MacPort::PortFile
# Description:
# Manipulate Port Files
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package MacPort::PortFile;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{fh}=shift;
    $self->{ftype}="gz";
    if( defined $self->{fh} )
    {
        $self->_read($self->{fh});
    }
    $self->{configure}=1;
    bless $self, $class;
    return $self;
}

sub setName {
    my $self=shift;
    $self->{name}=shift;
}

sub setVersion {
    my $self=shift;
    $self->{version}=shift;
}

sub setBzip {
    my $self=shift;
    $self->{ftype}="bzip";
}

sub setHomePage {
    my $self=shift;
    $self->{homepage}=shift;
}

sub setMaintainers {
    my $self=shift;
    push @{$self->{maintainers}}, @_;
}

sub setDescription {
    my $self=shift;
    $self->{description}=shift;
}

sub setLongDescription {
    my $self=shift;
    if( @_ ) {
        push @{$self->{ldescription}}, @_;
    }
}

sub setConfigure {
    my $self=shift;
    $self->{configure}=shift;
}

sub setConfigureArgs {
    my $self=shift;
    @{$self->{cargs}}=@_;
}

sub setBuildCmd {
    my $self=shift;
    $self->{build}=shift;
}

sub setSrcDir {
    my $self=shift;
    $self->{srcDir}=shift;
}


sub getDependencies {
    my $self=shift;
    return $self->{deps};
}

sub setDependencies {
    my $self=shift;
    @{$self->{deps}} = @_;
}

sub setPlatform {
    my $self=shift;
    @{$self->{platforms}} = @_;
}

sub getCheckSums {
    my $self=shift;
    return $self->{checksums};
}

sub setCheckSum {
    my $self=shift;
    my $type=shift;
    my $val=shift;
    $self->{checksums}{$type}=$val;
}

sub setArch {
    my $self=shift;
    $self->{arch}=shift;
}

sub arch {
    my $self=shift;
    return "all",if( ! defined $self->{arch} );
    return $self->{arch};
}

sub write {
    my $self=shift;
    my $fh=shift;
    if ( ! defined $fh ) { $fh=$self->{fh} };
    $self->_write($fh);
}

sub _write {
    my $self=shift;
    my $fh=shift;

    # -- standard stuff
    print $fh "# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4","\n";
    print $fh "PortSystem          1.0\n";
    print $fh "name                ", $self->{name}, "\n";
    print $fh "version             ", $self->{version}, "\n";
    if ( defined $self->{categories} ) {
        print $fh "category            ", join( " ", @{$self->{categories}} ), "\n";
    }
    print $fh "maintainers         ", join( " ", @{$self->{maintainers}} ), "\n";
    print $fh "description         ", $self->{description}, "\n";
    if (defined $self->{ldescription}) {
        print $fh "long_description";
        for ( @{$self->{ldescription}} ) {
            print $fh "\\\n", $_;
        }
        print $fh "\n";
    }
    print $fh "homepage            ", $self->{homepage}, "\n", if (defined $self->{homepage});
    print $fh "platforms           ", join( " ", @{$self->{platforms}} ), "\n";

    print $fh "worksrcdir          ", $self->{srcDir}, "\n", if (defined $self->{srcDir});


    # -- checksums
    if ( defined $self->{checksums} ) {
       print $fh "checksums           ";
       foreach my $csum ( keys %{$self->{checksums}} ) {
           print $fh $csum." ".$self->{checksums}{$csum},"\n";
       }
   }
   print $fh "use_bzip2           yes\n", if ( $self->{ftype} eq "bzip" );

    # -- dependencies
    if ( defined $self->{deps} ) {
       my $sep="depends_lib         ";
       foreach my $dep ( @{$self->{deps}} ) {
           print $fh $sep,"port:$dep";
           $sep=" \\\n                    ";
       }
       print $fh "\n";
   }

   # -- build instructions
   if ( ! $self->{configure} ) {
       print $fh "configure    {}\n", 
   }
   elsif ( $self->{configure}!~/^\d*/ ) {
       print $fh "configure {\n", '     system " cd \"${worksrcpath}\" && ', $self->{configure}, "\"\n}\n";
   }
   if ( defined $self->{cargs} ) {
       print $fh "configure.args    ", join( "  \\\n           ", @{$self->{cargs}});
       print $fh "\n";
   }
   print $fh "build {\n",'    system " cd \"${worksrcpath}\" && ', $self->{build}, "\"\n}\n",  if ( defined $self->{build} );
   print $fh "destroot {}\n";
}

sub _read {
    my $self=shift;
    my $fh=shift;

    # dependencies
}
