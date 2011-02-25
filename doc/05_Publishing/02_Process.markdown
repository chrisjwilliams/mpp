## The Publishing Process in The Software Release Cycle ##

Software is never perfect, and very rarely can a package be released into production
without going through a number of iterations to iron out painful bugs.
Even where the developers have done their utmost with systems, unit testing etc.
there are still a number of pitfalls to catch the unwary. Perhaps there is a level of 
user acceptance that need to be passed, or their are deployment details that need
attention for a particular platform (e.g. incompatible plugin search paths). 

Mpp directly supports the phased release concept, by allowing a number of release levels to
be defined. A typical list might be:

test, alpha, beta, user_acceptance, production

corresponding to the various groups of people who should have access to the
package at the stage of testing it represents. 
In this example, only the systems testing group would have access to
the "test" release. The package may go through several iterations at this level
before the systems group can certify the package for the next level in the list.

