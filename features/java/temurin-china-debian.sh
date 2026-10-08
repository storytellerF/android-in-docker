#!/usr/bin/env bash
set -euo pipefail
set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    apt-transport-https \
    ca-certificates \
    wget; \
    rm -rf /var/lib/apt/lists/*

set -eux; \
    install -d -m 0755 /etc/apt/keyrings; \
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public \
        | tee /etc/apt/keyrings/adoptium.asc > /dev/null; \
    distro_codename="$(awk -F= '/^(VERSION_CODENAME|UBUNTU_CODENAME)=/{print $2; exit}' /etc/os-release)"; \
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://mirrors.tuna.tsinghua.edu.cn/Adoptium/deb ${distro_codename} main" \
        > /etc/apt/sources.list.d/adoptium.list; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests \
    temurin-${OPENJDK_VERSION}-jdk; \
    rm -rf /var/lib/apt/lists/*
