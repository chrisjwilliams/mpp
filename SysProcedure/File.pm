# ----------------------------------
# class SysProcedure::File
# Description:
#    Allows you to describe/construct a file
#    on a remote or local machine.
#    Content can be from extracted from other files
#    (either local or on other machines), or added 
#    directly.
#-----------------------------------
# Methods:
# new(platform,filename) :
# execute([log],root) : create the file - location relative to root
# cat(@PlatformFiles) : add content from the specified files
# add(@text) : add direct content
#-----------------------------------

package SysProcedure::File;
use strict;
use Carp;
use PlatformFile;
use SysProcedure::ProcedureItem;
our @ISA=qw /SysProcedure::ProcedureItem/;
1;

sub new {
    my $class=shift;
    my $platform=shift;
    my $self=$class->SUPER::new($platform);
    my $filename=shift;
    $self->{destfile}=new PlatformFile($filename,$self->platform());
    @{$self->{items}}=();
    bless $self, $class;
    return $self;
}

sub execute {
    my $self=shift;
    my $log=shift;
    if( defined $log && ! UNIVERSAL::isa($log, 'GLOB') )
    {
        unshift @_, $log;
        $log = undef;
    }
    my $root=shift;

    my $fh=$self->{destfile}->fileHandle(">",$root);
    print $log "(", $self->{platform}->hostname(),") Creating File ",$self->{destfile}->fullFileName(),"\n", if(defined $log);

    my @content=@{$self->{items}};
    while(@content)
    {
        my $type=shift @content;
        if($type eq "cat") {
            my $platFile=shift @content;
            $platFile->isa("PlatformFile") or croak("expecting a Platform file");
            my $infh=$platFile->fileHandle("<");
            while(<$infh>) {
                print $fh $_;
            }
        }
        elsif( $type eq "line" ) {
            print $fh shift @content;
        }
        else {
            die("SysProcedure::execute() : unknown content type $type");
        }
    }
    $fh->close();
}

sub cat {
    my $self=shift;
    for(@_) {
        push @{$self->{items}}, "cat",$_;
    }
}

sub add {
    my $self=shift;
    for(@_) {
        push @{$self->{items}}, "line",$_;
    }
}
