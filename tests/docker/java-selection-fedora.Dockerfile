FROM fedora:43
RUN dnf install -y java-25-openjdk-devel && dnf clean all
ENV JAVA_HOME=/usr/local/java/current
ENV PATH=${JAVA_HOME}/bin:${PATH}
COPY features/_common/ /tmp/_common/
COPY features/java/ /tmp/java/
RUN PROVIDER=openjdk VERSION=21 SOURCE=default bash /tmp/java/install.sh
