ARG BASE_SYSTEM=arch
ARG BASE_VERSION=latest
ARG DESKTOP_TYPE=xfce
ARG DESKTOP_IMAGE_REGION_SUFFIX=
ARG DESKTOP_IMAGE_LABEL=latest
FROM storytellerf/desktop-in-docker:${BASE_SYSTEM}-${BASE_VERSION}-${DESKTOP_TYPE}${DESKTOP_IMAGE_REGION_SUFFIX}-${DESKTOP_IMAGE_LABEL}

ARG OPENJDK_VERSION=21
ARG TEMURIN_ARCH=x64

ENV JAVA_HOME=/opt/temurin-${OPENJDK_VERSION}
ENV PATH=${JAVA_HOME}/bin:${PATH}

USER root

RUN pacman -Sy --noconfirm --needed ca-certificates tar wget \
    && pacman -Scc --noconfirm

RUN install -d -m 0755 /opt/temurin-download /opt/temurin-${OPENJDK_VERSION} \
    && wget -O /opt/temurin-download/jdk.tar.gz "https://api.adoptium.net/v3/binary/latest/${OPENJDK_VERSION}/ga/linux/${TEMURIN_ARCH}/jdk/hotspot/normal/eclipse?project=jdk" \
    && tar -xzf /opt/temurin-download/jdk.tar.gz -C /opt/temurin-${OPENJDK_VERSION} --strip-components=1 \
    && rm -rf /opt/temurin-download
