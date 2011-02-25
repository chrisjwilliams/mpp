## Publishing ##

So now you have built your package, its time to make it available to others. Each platform
expects to find packages in different ways. For example, debian based systems use the apt
system to download and install packages, Fedora uses yum, and MacOSX has a whole host of options 
such as macPorts and .dmg files.

Mpp comes to the rescue by hiding all this complexity from the user. Once a package is ready
for release, the user simply has to give the command and the appropriate packages will find
their way to the appropriate distribution mechanisms for each supported platform.

