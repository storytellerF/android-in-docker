#!/usr/bin/env bash
set -euo pipefail
OPENJDK_VERSION="${OPENJDK_VERSION:-21}"

pacman -Sy --noconfirm --needed \
    jdk${OPENJDK_VERSION}-openjdk \
    && pacman -Scc --noconfirm
