#!/usr/bin/env bash
set -euo pipefail
apt-get update && DEBIAN_FRONTEND=noninteractive \
    apt-get install -y --no-install-recommends --no-install-suggests ca-certificates wget gpg apt-transport-https && \
    rm -rf /var/lib/apt/lists/*

wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg && \
    install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg && \
    rm -f microsoft.gpg && \
    printf 'Types: deb\nURIs: https://packages.microsoft.com/repos/code\nSuites: stable\nComponents: main\nArchitectures: amd64,arm64,armhf\nSigned-By: /usr/share/keyrings/microsoft.gpg\n' \
        > /etc/apt/sources.list.d/vscode.sources

apt update && DEBIAN_FRONTEND=noninteractive \
    apt install -y --no-install-recommends --no-install-suggests code && \
    rm -rf /var/lib/apt/lists/*
