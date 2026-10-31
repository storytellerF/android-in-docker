#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SYSTEM_ID=$( . /etc/os-release; printf '%s' "$ID")
case "$SYSTEM_ID" in
    debian|ubuntu)
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends git bash ca-certificates wget unzip sudo
        rm -rf /var/lib/apt/lists/*
        bash "$SCRIPT_DIR/vscode/debian.sh"
        ;;
    fedora)
        dnf install -y git bash ca-certificates wget unzip sudo
        dnf clean all
        bash "$SCRIPT_DIR/vscode/fedora.sh"
        ;;
    alpine)
        apk add --no-cache git bash ca-certificates wget unzip sudo
        ;;
    arch)
        pacman -Sy --noconfirm --needed git bash ca-certificates wget unzip sudo
        pacman -Scc --noconfirm
        ;;
    *) echo "Unsupported distribution: $SYSTEM_ID" >&2; exit 1 ;;
esac
