# ----------------------------------
# class RoleMaster::FileDBDriver
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package RoleMaster::FileDBDriver;
use strict;
use DBI;
use RoleMaster::DBDriver;
our @ISA=qw /RoleMaster::DBDriver/;
1;

sub new {
    my $class=shift;
    my $dir=shift;
    my $db=$dir."/db";
    my $init=1;
    if( ! -d $dir ) {
        mkdir $dir or die "unable to create directory $dir for the user database";
    }
    if( ! -f $db )
    {
        $init=0;
    }
    my $dbh = DBI->connect(
        'DBI:SQLite:dbname='.$db,
        { RaiseError => 1, AutoCommit => 1 })
        or die $DBI::errstr;

    my $self=$class->SUPER::new($dbh);
    bless $self, $class;
    if( ! $init ) { $self->setup(); };
    return $self;
}

