#!/usr/bin/env bash
set -euo pipefail
OPENJDK_VERSION="${OPENJDK_VERSION:-21}"

apk add --no-cache ca-certificates wget

wget -O /etc/apk/keys/adoptium.rsa.pub https://packages.adoptium.net/artifactory/api/security/keypair/public/repositories/apk \
    && printf '%s\n' 'https://packages.adoptium.net/artifactory/apk/alpine/main' >> /etc/apk/repositories \
    && apk update

apk add --no-cache temurin-${OPENJDK_VERSION}-jdk
