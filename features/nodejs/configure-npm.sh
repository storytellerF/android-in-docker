#!/usr/bin/env bash
set -euo pipefail
USERNAME="${_REMOTE_USER:?Dev Container remote user is required}"
if [ "$USERNAME" != root ] && ! command -v sudo >/dev/null; then
    SYSTEM_ID=$( . /etc/os-release; printf '%s' "$ID")
    case "$SYSTEM_ID" in
        debian|ubuntu) apt-get update && apt-get install -y --no-install-recommends sudo && rm -rf /var/lib/apt/lists/* ;;
        alpine) apk add --no-cache sudo ;;
        arch) pacman -Sy --noconfirm --needed sudo && pacman -Scc --noconfirm ;;
        fedora) dnf install -y sudo && dnf clean all ;;
        *) echo "Unsupported distribution: $SYSTEM_ID" >&2; exit 1 ;;
    esac
fi
npm config set registry "$NPM_REGISTRY" --global
if [ "$USERNAME" = root ]; then
    npm config set registry "$NPM_REGISTRY"
else
    sudo -u "$USERNAME" -H -- env PATH="$PATH" npm config set registry "$NPM_REGISTRY"
fi
