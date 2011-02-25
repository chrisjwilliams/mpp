## Developing new Publisher Plugins ##

Publisher packages come in two parts corresponding to the
server and client sides, named Publisher and Publisher::Installer respectively.

## Publisher packages ##

Source Location    : Publishers
Package nameing    : Publishers::<Publisher_name>
Nameing convention : Publisher_name must start with a capital letter
Base Class         : Packagers::Base
Specification      : specify the use of this publisher in the appropriate
                     [publisher] section:
                     type=<publisher_name> (n.b. name not capitalised)

<b>Publisher Interface Requirements</b>

1) sub packageTypes()
   This method must return the names of the Package types it is able
   to publish. e.g.:
<code>
   sub packageTypes() {
        return qw(Rpm); # publisher for rpm files
   }
</code>

2) 

## Installer packages ##

Source Location : Publishers/Installer
Package nameing : Publishers::Installer::<Installer_name>
Nameing convention : Installer_name must start with a capital letter
Platform Setup : In [packager] section of platform definition specify
                 the installer client type with :
                 type=<installer_name> (N.B. uncapitalised)
Base Class     : Packagers::Installer::Base

<b>Installer Interface Requirements</b>

1) sub packageTypes()
Installers may handle package types of one or more flavours. These should be
returned as a list of Packager Modules with the packageTypes method:

e.g.

<code>
sub packageTypes() {
    return qw(Rpm);
}
</code>

2) sub repositoryTypes()
Installers may interact with one or more publisher type. These types should be
returned by the repositoryTypes() method:

e.g.

<code>
sub repositoryTypes() {
    return qw(Yum);
}
</code>

3) sub updatePackageInfoCommand(@Publishers)
Return the command line instructions to run that updates information about available
packages in the specified publisher.

4) sub installPackageCmd(package_list)
This method should return the command(s) required to install the specified packages.

5) sub uninstallPackageCmd(@list_of_packages)
This method should return the command(s) required to uninstall the specified packages.

6) sub addRepositoryProcedure(Publisher, release_level)
Return a SysProcedure::Procedure object detailing how to add a Publisher to the 
systems package manager/installation system.

7) sub removeRepository(Publisher, release_level)
actually remove the repository from the system
