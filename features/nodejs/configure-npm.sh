#!/usr/bin/env bash
set -euo pipefail
USERNAME="${_REMOTE_USER:?Dev Container remote user is required}"
SYSTEM_ID=$( . /etc/os-release; printf '%s' "$ID")
case "$SYSTEM_ID" in
    debian|ubuntu) SYSTEM=debian ;;
    alpine|arch|fedora) SYSTEM="$SYSTEM_ID" ;;
    *) echo "Unsupported distribution: $SYSTEM_ID" >&2; exit 1 ;;
esac
case "$SYSTEM" in
    debian) apt-get update && apt-get install -y --no-install-recommends sudo && rm -rf /var/lib/apt/lists/* ;;
    alpine) apk add --no-cache sudo ;;
    arch) pacman -Sy --noconfirm --needed sudo && pacman -Scc --noconfirm ;;
    fedora) dnf install -y sudo && dnf clean all ;;
esac
NPM_CONFIG_REGISTRY=https://registry.npmmirror.com npm install -g nrm
nrm use tencent
sudo -u "$USERNAME" -H -- env PATH="$PATH" nrm use tencent
npm config set registry "$NPM_REGISTRY" --global
sudo -u "$USERNAME" -H -- npm config set registry "$NPM_REGISTRY"
