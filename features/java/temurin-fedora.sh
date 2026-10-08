#!/usr/bin/env bash
set -euo pipefail
OPENJDK_VERSION="${OPENJDK_VERSION:-21}"

dnf install -y ca-certificates wget rpm \
    && dnf clean all

rpm --import https://packages.adoptium.net/artifactory/api/gpg/key/public \
    && printf '[Adoptium]\nname=Adoptium\nbaseurl=https://packages.adoptium.net/artifactory/rpm/fedora/$releasever/$basearch\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.adoptium.net/artifactory/api/gpg/key/public\n' \
        > /etc/yum.repos.d/adoptium.repo

dnf install -y temurin-${OPENJDK_VERSION}-jdk \
    && dnf clean all
