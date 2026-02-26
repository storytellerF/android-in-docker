FROM storytellerf/android-in-docker:snapshot

USER root

RUN apt update && apt install -y openssh-server

RUN echo "debian:123456" | chpasswd

USER debian

EXPOSE 22
