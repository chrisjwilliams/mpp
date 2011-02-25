# Dependency Variables #

Defined packages may define a number of variables. Typically these will refer to the location of various
different resources provided by that package. 


In the most common case, you should use the version independent format :

${pack::<it>package_name</it>::<it>variable_name</it>}

In the rare cases where dependencies involve two versions of the same package use the version
dependent format:

${pack::<it>package_name</it>::<it>package_version</it>::<it>variable_name</it>}
