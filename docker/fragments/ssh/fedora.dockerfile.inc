USER root

RUN dnf install -y openssh-server && dnf clean all
