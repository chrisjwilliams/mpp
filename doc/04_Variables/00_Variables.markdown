## MPP Variables ##

# Introduction #

A number of variables are automatically set, or can be specified in Mpp to give a wide 
range of information within configuration files, patches and other project files.

Mpp variables all take the form ${<it>variable_name</it>}. 

To avoid expanding a string that takes the above form, prefix it with an additional $ symbol.
e.g. $${<it>variable_name</it>} will not be expanded.

Beware that if the variable specified does not
exist, the variable does not default to the empty string but will be left unexpanded.

Generally variables will exist within a namespace which should be prefixed to the variable name,
seperated by a double colon (::). 

e.g. ${install::lib} will refer to the lib variable inside the install namespace.

Multiple namespaces may exist - each separated by a double colon.

# Configuration Variables #
 
Some global variables are defined that are available for use in general configuration
files, but not in project configuration files.

Variable Name                     | Description
------------------------------------------------------------------------------------------------------
${home}                           | The current users home directory

# Variables in the Project Configuration File #

Generally, all the variables described in this chapter are available for use when writing
a project configuration file. In addition, a number of user-defined variables can be defined
on a platform by platform basis.


# Expanding Variables in Other Project Files #

Variables can be specified in other project files. The copy and patch mechanisms described
elsewhere have variable expanding equivalents (copyExpand and patchExpand), which will first
parse the file, expanding any variables to their values, before copying or applying the patch.

