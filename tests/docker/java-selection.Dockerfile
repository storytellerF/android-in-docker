FROM debian:trixie AS openjdk
ENV JAVA_HOME=/usr/local/java/current
ENV PATH=${JAVA_HOME}/bin:${PATH}
COPY features/_common/ /tmp/_common/
COPY features/java/ /tmp/java/
RUN PROVIDER=openjdk VERSION=21 SOURCE=default bash /tmp/java/install.sh

FROM openjdk AS temurin
RUN PROVIDER=temurin VERSION=21 SOURCE=default bash /tmp/java/install.sh

FROM temurin AS openjdk-again
RUN PROVIDER=openjdk VERSION=21 SOURCE=default bash /tmp/java/install.sh
