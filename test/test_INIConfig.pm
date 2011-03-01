# ----------------------------------
# class test_INIConfig
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_INIConfig;
use TestUtils::TestPackage;
use strict;
use INIConfig;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    return $self;
}

sub tests {
    return qw(removeVar removeItemFromList definedSection);
}

sub definedSection {
    my $self=shift;

    my $config = INIConfig->new();
    my $section = "pack::c++";
    die("section $section should not be defined"), if ($config->definedSection($section) );
    $config->setVar("pack::c", "testval", "testval"); # add a var that looks right if not escaped properly
    die("section $section should not be defined, whereas c is defined!"), if ($config->definedSection( "\Q$section\E") );

    $config->setVar($section, "testval", "testval");
    die("section $section should be defined"), if ( ! $config->definedSection( qr/\Q$section\E/ms));

    #my $tag="pack\:\:c\+\+(::.+)?";
    my $tag = qr/\Q$section\E(::.+)?/ms; # regex as a variable
    foreach my $s2 ( 'pack\:\:c\+\+', 'pack::c\+\+(::.+)?', "\Q$section\E", "\Q$section\E"."(::.+)?", qr/pack::\Qc++\E/m , qr/\Qpack::c++\E(::.+)?/ms, $tag ) {
        die("section $s2 should be defined"), if ( ! $config->definedSection($s2) );
    }

}

sub removeVar{
    my $self=shift;
    my $section="dummy";
    my $var = "testvar";
    my $val = "testval";

    # Use case
    # No section exists
    # Expect:
    # quietly return
    {
        my $config = INIConfig->new();
        $config->removeVar($section, $var);
    }
    # Use case
    # section exists, but var does not
    # Expect:
    # quietly return
    {
        my $config = INIConfig->new();
        $config->setVar($section,"other",$val);
        $config->removeVar($section, $var);
        die("item removed unexpectedly"), if( ! defined $config->var($section,"other"));
    }
    # Use case
    # section exists, var exists
    # Expect:
    # remove variable
    {
        my $config = INIConfig->new();
        $config->setVar($section,$var,$val);
        $config->removeVar($section, $var);
        die("item not removed"), if( defined $config->var($section,$var));
    }

}

sub removeItemFromList {
    my $self=shift;
    my $section="dummy";
    my $var = "testvar";
    my $val = "testval";

    # Use case
    # No section exists
    # Expect:
    # quietly return
    {
        my $config = INIConfig->new();
        my @l = $config->list($section);
        die("expecting -1 length, got $#l"), if( $#l != -1 );
        $config->removeItemFromList($section, $var);
    }

    # Use case
    # section exists but no var exists
    # Expect:
    # quietly return - unchanged list
    {
        my $config = INIConfig->new();
        $config->setList($section,$var);
        my @l = $config->list($section);
        die("expecting 1 item( 0 length), got ".($#l+1)." (@l)"), if( $#l != 0 );
        $config->removeItemFromList($section, "notexist");
        @l = $config->list($section);
        die("expecting 1 item( 0 length), got $#l (@l)"), if( $#l != 0 );
    }

    # Use case
    # section exists and var exists
    # Expect:
    # remove from list
    {
        my $config = INIConfig->new();
        $config->setList($section,$var);
        my @l = $config->list($section);
        die("expecting 1 item, got ".($#l + 1).")"), if( $#l != 0 );
        $config->removeItemFromList($section, $var );
        @l = $config->list($section);
        die("expecting 0 items, got ".($#l + 1)."(@l)"), if( $#l != -1 );
    }
}

