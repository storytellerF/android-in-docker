ARG BASE_SYSTEM=alpine
ARG BASE_VERSION=latest
ARG DESKTOP_TYPE=xfce
ARG DESKTOP_IMAGE_REGION_SUFFIX=
ARG DESKTOP_IMAGE_LABEL=latest
FROM storytellerf/desktop-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}${DESKTOP_IMAGE_REGION_SUFFIX}-${DESKTOP_IMAGE_LABEL}

ARG OPENJDK_VERSION=21

USER root

RUN apk add --no-cache ca-certificates wget

RUN wget -O /etc/apk/keys/adoptium.rsa.pub https://packages.adoptium.net/artifactory/api/security/keypair/public/repositories/apk \
    && printf '%s\n' 'https://packages.adoptium.net/artifactory/apk/alpine/main' >> /etc/apk/repositories \
    && apk update

RUN apk add --no-cache temurin-${OPENJDK_VERSION}-jdk
