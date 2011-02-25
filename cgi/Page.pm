# ----------------------------------
# class Page
# Description:
#
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package Page;
use strict;
use Redirection;
use RoleMaster::Role;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{cgi}=shift;
    $self->{api}=shift;
    $self->{session}=shift;
    bless $self, $class;
    return $self;
}

sub setGroup {
    my $self=shift;
    $self->{group}=shift;
}

sub roles {
    my $self=shift;
    my $userRole = new RoleMaster::Role("user");
    my $adminRole = new RoleMaster::Role("admin");
    $adminRole->setSubserviantRoles($userRole);
    return ($userRole,$adminRole);
}


sub name {
    my $self=shift;
    my $type=ref($self);
    $type=~s/.*::(.*)/$1/g; # strip off name space
    return $type;
}

sub groupName {
    my $self=shift;
    return $self->name();
}

sub title {
    my $self=shift;
    return $self->name();
}

sub body {
    my $self=shift;
    my $fh=shift;
    print $fh "Error: Unknown Page requested";
}

#
# Generate a form that calls self with an action
#
sub formStart {
    my $self=shift;
    my $fh=shift;
    my $action=shift;
    print $fh "<form action=\"", $self->url(), "\" method=\"POST\">\n";
    print $fh "<input type=\"hidden\" name=\"action\" value=\"",$action,"\" >\n";
    print $fh "<input type=\"hidden\" name=\"page\" value=\"",($self->name())."\" >\n";
}

sub formEnd {
    my $self=shift;
    my $fh=shift;
    my $button=shift;
    print $fh "<input type=\"submit\" value=\"$button\" >\n";
    print $fh "</form>\n";
}

sub url {
    my $self=shift;
    my $vars=shift;
    my $session="CGISESSID";
    my $sid=($self->{cgi}->cookie($session) || $self->{cgi}->param($session));
    my $url=$self->{cgi}->script_name()."?";
    $vars->{$session}=$sid, if ( defined $sid );
    $vars->{"page"}=$self->name(), if( !defined $vars->{"page"} );
    my $sep="";
    foreach my $key ( keys %{$vars} )
    {
        $url .= $sep.$key."=".$vars->{$key};
        $sep=";";
    }
    return $url;
}

sub check {
    return 1;
}

sub execute {
    return "";
}
