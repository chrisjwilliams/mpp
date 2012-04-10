# Top level Variables #

These variables exist in the top level namespace

Variable Name                     | Description
------------------------------------------------------------------------------------------------------
${name}                           | The name of the project
${version}                        | The project version
${prefix}                         | The temporary location on the build platform for a build to install files
${srcdir}                         | The top directory name of the unpacked src code
${testdir}                        | The working directory where test data etc is uploaded to


# Installation Variables #

These variables exist in the *install* namespace. They refer
to locations on the target machine, and are set by the platform
descriptions.

Variable Name                      | Description
------------------------------------------------------------------------------------------------------
${install::bin}                    | The binary installation location (e.g. /usr/bin )
${install::config}                 | System wide configuration files (e.g. /etc )
${install::data}                   | The location to install application specific fixed data (e.g. /usr/share )
${install::doc}                    | The location to install application documents (e.g. /usr/share/doc )
${install::include}                | Installation location for developers header files (e.g. /usr/include )
${install::lib}                    | The library installation location (e.g. /usr/lib ) (n.b. does not trigger an ldconfig)
${install::man}                    | The location to install application man pages (e.g. /usr/share/man )
${install::python_lib}             | The python library installation location (e.g. /usr/lib/python )
${install::shared}                 | The library installation location for shared libraries (e.g. /usr/lib )

# Platform Variables #

Variable Name                      | Description
------------------------------------------------------------------------------------------------------
${platform::arch}                  | The architecture of the current platform e.g. amd64, i386
${platform::type}                  | The type of current platform (mpp specific)
${platform::platform}              | The os platform of the current platform e.g. ubuntu_10_10
${command::perl}                   | The perl executable
${command::python}                 | The python executable
