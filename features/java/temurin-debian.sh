#!/usr/bin/env bash
set -euo pipefail
OPENJDK_VERSION="${OPENJDK_VERSION:-21}"

set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    apt-transport-https \
    ca-certificates \
    gpg \
    wget; \
    rm -rf /var/lib/apt/lists/*

set -eux; \
    wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | gpg --dearmor \
        | tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null; \
    distro_codename="$(awk -F= '/^(VERSION_CODENAME|UBUNTU_CODENAME)=/{print $2; exit}' /etc/os-release)"; \
    echo "deb https://packages.adoptium.net/artifactory/deb ${distro_codename} main" \
        > /etc/apt/sources.list.d/adoptium.list; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    temurin-${OPENJDK_VERSION}-jdk; \
    rm -rf /var/lib/apt/lists/*
