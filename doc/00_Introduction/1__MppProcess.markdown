Introduction - What is MPP?
===========================

MPP is a tool developed within the radio astronomy community to ease the 
complexity and cost of deploying computer software across multiple-platforms. 

Each platform has its own conventions, standards, package managers and packaging 
formats for deploying software. MPP allows the user to describe a software product 
in generic terms (e.g this is a binary, this is a library, this is documentation, 
it requires these dependencies), and will produce a suitable package tailored to 
each supported platform, that can be easily installed by the user in the normal 
way native to that platform.

It consists of three Process layers: Build, Test and Publish and is designed to 
support the entire release and testing processes. Each of these processes can 
be launched with a single mpp command.

The Build
---------
With a suitable description file, the source code and access to the supported 
platforms, MPP will create suitable packages containing the build products. 
These packages are transferred from the platform on which they were built, 
to a central repository for testing and deployment.

Testing
-------
For each supported platform, it is important to try out the packages built in 
the previous stage to ensure they work for a typical user. Clean images for 
each platform are used (i.e. one without any  dependencies or development 
products installed), and any problems with the install are reported back for 
fixing. Additional post-install testing scripts can also be specified.

Publication
-----------
Now we have packages that work, they are ready to be distributed to the wider 
community. MPP allows you to publish these packages to suitable repositories 
(again platform specific) from which other users may install the packages on 
their machines directly. MPP supports multiple level of publishing to allow 
you to tailor your release process (e.g. a repository for beta-testers, one 
for supported releases etc.).

