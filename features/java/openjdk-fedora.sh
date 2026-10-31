#!/usr/bin/env bash
set -euo pipefail
OPENJDK_VERSION="${OPENJDK_VERSION:-21}"

dnf install -y \
    java-${OPENJDK_VERSION}-openjdk-devel \
    && dnf clean all

rpm -ql --noghost "java-${OPENJDK_VERSION}-openjdk-devel" | bash "$(dirname "$0")/record-home.sh"
