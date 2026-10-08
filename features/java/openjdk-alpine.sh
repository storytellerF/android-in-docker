#!/usr/bin/env bash
set -euo pipefail
OPENJDK_VERSION="${OPENJDK_VERSION:-21}"

apk add --no-cache \
    openjdk${OPENJDK_VERSION}
