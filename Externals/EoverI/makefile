#CLASSPATH=".:/home/cwilliams/Projects/cbs/dev/demo/jar/lib/*:/home/cwilliams/Projects/cbs/dev/demo/jar/3rdParty/*"
#EOVERI_DIR:=/home/cwilliams/Projects/cbs/dev/demo/catalogue.cloudprovider.service.eoveri.com/jar
EOVERI_VERSION=flessr-2011-02-18
COMMONS_CLI_DIR=/usr/share/maven-repo/commons-cli/commons-cli/1.1
EOVERI_DIR:=/home/cwilliams/Projects/cbs/dev/demo/${EOVERI_VERSION}/jars
#CLASSPATH=".:${EOVERI_DIR}/*:${COMMONS_CLI_DIR}/*"
CLASSPATH="${EOVERI_DIR}/lib/*:${EOVERI_DIR}/3rdParty/*:${COMMONS_CLI_DIR}/*"
JAVAC=javac
JAVA=java

all: EoverICLI.class zeeli-cli

zeeli-cli: makefile
	@echo "#!/bin/bash" > $@
	@echo "${JAVA} -classpath `pwd`:${CLASSPATH} EoverICLI \"\$$@"\" >> $@
	@chmod +x $@

clean:
	rm *.class

%.class: %.java
	$(JAVAC) -classpath ${CLASSPATH} $<

run:
	${JAVA} -classpath ${CLASSPATH} EoverICLI
