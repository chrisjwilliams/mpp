# -----------------------------------------------
# Publisher
# -----------------------------------------------
# Description: 
#
#
#
# -----------------------------------------------
# Copyright Chris Williams 2003
# -----------------------------------------------
# Interface
# ---------
# new()    : new object
#
#

package Publisher;
use strict;
1;

# -- initialisation

sub new {
    my $class=shift;

    my $self={};
    bless $self, $class;

    return $self;
}

# -- private methods -------------------------

