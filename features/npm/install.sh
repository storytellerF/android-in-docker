#!/usr/bin/env bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERNAME="${USERNAME:-${_REMOTE_USER:-automatic}}"
if [ "$USERNAME" = automatic ]; then
    USERNAME=$(awk -F: '$3 == 1000 {print $1; exit}' /etc/passwd)
    USERNAME="${USERNAME:-root}"
fi
USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
[ -n "$USER_HOME" ] || { echo "Unknown user: $USERNAME" >&2; exit 1; }
USER_UID=$(id -u "$USERNAME")
USER_GID=$(id -g "$USERNAME")
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
npm config set registry "$REGISTRY" --global
sudo -u "$USERNAME" -H -- npm config set registry "$REGISTRY"
