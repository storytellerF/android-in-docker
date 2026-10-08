#!/usr/bin/env bash
set -euo pipefail
OPENJDK_VERSION="${OPENJDK_VERSION:-21}"

TEMURIN_ARCH="${TEMURIN_ARCH:-x64}"

export JAVA_HOME=/opt/temurin-${OPENJDK_VERSION}

export PATH=${JAVA_HOME}/bin:${PATH}

pacman -Sy --noconfirm --needed ca-certificates tar wget \
    && pacman -Scc --noconfirm

install -d -m 0755 /opt/temurin-download /opt/temurin-${OPENJDK_VERSION} \
    && wget -O /opt/temurin-download/jdk.tar.gz "https://api.adoptium.net/v3/binary/latest/${OPENJDK_VERSION}/ga/linux/${TEMURIN_ARCH}/jdk/hotspot/normal/eclipse?project=jdk" \
    && tar -xzf /opt/temurin-download/jdk.tar.gz -C /opt/temurin-${OPENJDK_VERSION} --strip-components=1 \
    && rm -rf /opt/temurin-download
