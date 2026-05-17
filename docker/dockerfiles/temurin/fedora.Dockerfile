ARG BASE_SYSTEM=fedora
ARG BASE_VERSION=44
ARG DESKTOP_TYPE=xfce
ARG DESKTOP_IMAGE_REGION_SUFFIX=
ARG DESKTOP_IMAGE_LABEL=latest
FROM storytellerf/desktop-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}${DESKTOP_IMAGE_REGION_SUFFIX}-${DESKTOP_IMAGE_LABEL}

ARG OPENJDK_VERSION=21

USER root

RUN dnf install -y ca-certificates wget rpm \
    && dnf clean all

RUN rpm --import https://packages.adoptium.net/artifactory/api/gpg/key/public \
    && printf '[Adoptium]\nname=Adoptium\nbaseurl=https://packages.adoptium.net/artifactory/rpm/fedora/$releasever/$basearch\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public\n' \
        > /etc/yum.repos.d/adoptium.repo

RUN dnf install -y temurin-${OPENJDK_VERSION}-jdk \
    && dnf clean all
