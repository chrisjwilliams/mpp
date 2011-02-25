# ----------------------------------
# class test_Environment
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package test_Environment;
use strict;
use Environment;
1;

sub new {
    my $class=shift;
    my $self={};
    bless $self, $class;
    $self->{testConfigDir}=shift;
    $self->{tmpdir}=shift;
    return $self;
}

sub tests {
    return qw( test_size test_remove test_expand test_merge );
}

sub test_size {
    my $self=shift;
    my $env=$self->_initEnv();
    my $esize=3;
    my $size=$env->size();
    die("expecting $esize, got $size"), if( $esize != $size );

    # empty environment
    my $env2=Environment->new();
    $size=$env2->size();
    die("expecting 0, got $size"), if( $size != 0 );

}

sub test_remove {
    my $self=shift;
    my $env=$self->_initEnv();
    my $esize=$env->size();
    my $env2=$self->_initEnv();

    # -- remove identical environment
    $env2->remove($env);
    my $size=$env2->size();
    die("expecting empty environment, got $size elements"), if( $size != 0 );

    # remove null environment
    my $env3=Environment->new();
    $env->remove($env3);
    $size=$env->size();
    die("expecting $esize elements, got $size elements"), if( $size != $esize );

}

sub test_expand {
    my $self=shift;

    # -- simple expand without namespaces
    my $env=$self->_initEnv();
    my $string='${a}+$${a}-${b}*$${b} ${bad} ${b}'."\n";
    my $estring='1+$${a}-2*$${b} ${bad} 2'."\n";
    $string=$env->expandString($string);
    die("expecting\n\t\t$estring\n\tgot\n\t\t$string"), if($estring ne $string);

    # -- simple expand with meta characters in name
    $string=$env->expandString('${c++}');
    my $cppstring='cpp';
    die("expecting\n\t\t$cppstring\n\tgot\n\t\t$string"), if($cppstring ne $string);


    # -- expand with namespaces
    $env->namespace("fred","george");
    $string='${fred::a}+$${a}-${george::b}*$${b} ${bad} ${fred::b}'."\n";
    $string=$env->expandString($string);
    die("expecting\n\t\t$estring\n\tgot\n\t\t$string"), if($estring ne $string);

    # -- expand mixed namespaces/no namespace
    my @enamesp=sort( "fred::","" );
    my @namespaces=sort($env->namespace("fred",""));
    die("expecting\n\t\t@enamesp\n\tgot\n\t\t@namespaces"), if("@namespaces" ne "@enamesp");

    $string='${fred::a}+$${a}-${b}*$${b} ${bad} ${b}'."\n";
    $string=$env->expandString($string);
    die("expecting\n\t\t$estring\n\tgot\n\t\t$string"), if($estring ne $string);
}

sub test_merge {
    my $self=shift;
    my $env=$self->_initEnv();

    # -- test merge of item with local variable
    $env->merge( { c=>'${a}', d=>'${c}' } );
    my $expect=1;
    my $val=$env->var("c");
    my $string=$env->expandString('${c}');
    die("expecting $expect, got $string"), if( $expect ne $string );
    die("expecting $expect, got $val"), if( $expect ne $val );
    $val=$env->var("d");
    $string=$env->expandString('${d}');
    die("expecting $expect, got $string"), if( $expect ne $string );
    die("expecting $expect, got $val"), if( $expect ne $val );

}

sub _initEnv {
    my $self=shift;
    my $env=Environment->new(
                    { a=>1,
                      b=>2,
                      'c++'=>'cpp'
                    }
                );
    return $env;
}

