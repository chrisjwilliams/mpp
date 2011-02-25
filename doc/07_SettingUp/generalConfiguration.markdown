## General Configuration ##

# Introduction #
The packaging system needs to be configured to tell it things such as where
to pick up platform and project information. This is done through one or more
configuration files. 

Generally, all configuration files (files called mpp.conf) found in the 
configuration path, will be used. Those files found later in the path will
be merged into earlier versions, with the later ones taking precedence if
they conflict. In addition, any files of any name found in the configuration
directories will be treated as configuration files and loaded in the same way.

You can see the configuration path, configurationDirectories , and a list of all 
configuration files found in this path with the -config option.

# The [localhost] section #
The [localhost] section allows you to specify one, or more files that describe
the local platform. This file will take the format of any other Platform description
file. If you do not specify a localhost file then an attempt will be made to
guess what your local system is.

# The [projectLocation] section #
This section allows you to specify a list of directories in which project information
can be found.

# The [platformLocation] section #
This section allows you to specify a list of directories in which platform information
can be found.

# The [mpp] section #
in this section you must define:

Name                     | Description
---------------------------------------------------------------------------------------------------
workDir                  | A location on the local machine in which to store temporary files

