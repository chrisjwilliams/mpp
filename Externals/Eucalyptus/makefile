#CLASSPATH=".:/home/cwilliams/Projects/cbs/dev/demo/jar/lib/*:/home/cwilliams/Projects/cbs/dev/demo/jar/3rdParty/*"
#EOVERI_DIR:=/home/cwilliams/Projects/cbs/dev/demo/catalogue.cloudprovider.service.eoveri.com/jar
#CLASSPATH=".:${EOVERI_DIR}/lib/*:${EOVERI_DIR}/3rdParty/*"
EOVERI_VERSION=oerc-2011-01-11
EOVERI_DIR:=/home/cwilliams/Projects/cbs/dev/demo/${EOVERI_VERSION}/jars
CLASSPATH=".:${EOVERI_DIR}/*"
JAVAC=javac

all: EucalyptusCLI.class SimpleOercClientExampleForChris.class

%.class: %.java
	$(JAVAC) -classpath ${CLASSPATH} $<


EucalyptusCLI.class: EucalyptusCLI.java
	javac -classpath ${CLASSPATH} EucalyptusCLI.java

run:
	java -classpath ${CLASSPATH} EucalyptusCLI
