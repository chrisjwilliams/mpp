# ----------------------------------
# class RoleMaster::Widgets::GroupManager
# Description:
#   A HTML Widget for managing groups
#-----------------------------------
# Methods:
# new() :
#-----------------------------------


package RoleMaster::Widgets::GroupManager;
use CGI::Widget::Tabs;
use strict;
1;

sub new {
    my $class=shift;
    my $self={};
    $self->{cgi}=shift;
    $self->{group}=shift;

    # defaults
    $self->{cmd}="gmgr";
    bless $self, $class;
    return $self;
}

sub setCommand {
    my $self = shift;
    $self->{cmd}=shift;
}

sub execute {
    my $self = shift;
}

sub render {
    my $self = shift;
    my $fh = shift;

    my $gp=$self->{group};
    my @tabs;
    foreach my $role ( $gp->roles() ) {
        push @tabs, $role->name();
    }

    my $role = "role";
    my $currentRole=$self->{cgi}->param($role);
    if( $#tabs > 0 ) {
        my $tab = CGI::Widget::Tabs->new;
        $tab->cgi_object($self->{cgi});
        $tab->cgi_param($role);
        $tab->headings( @tabs );
        $tab->wrap(5);
        $tab->default($tabs[0]);
        print $fh $tab->render();
        print $fh "<br>\n";
    }

    my $action=$self->{cmd};

    print $fh "<form action=\"", $self->{cgi}->self_url(), "\" method=\"POST\">\n";
    print $fh "<input type=\"hidden\" name=\"action\" value=\"",$action,"\" >\n";
    print $fh "<table>";
    print $fh "<tr><th>Id</th><th>Name</th></tr>\n";
    foreach my $user ( $gp->listMembers($currentRole) ) {
        if( defined $user ) {
        print $fh "<tr><td>",$user->id(),"</td>",
                  "<td>", $user->fullName(), "</td>",
                  "<td><input type=\"checkbox\" name=\"users\" ",
                  "value=\"", $user->id(), "\" /></td>",
                  "</tr>";
        }
    }
    print $fh "</table>\n";
    print $fh "<input type=\"submit\" value=\"remove\" >\n";
    print $fh "</form>";
}
