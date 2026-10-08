#!/usr/bin/env bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/source-selection.sh"
resolve_feature_source NODEJS_SOURCE
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
if [ "$FEATURE_SELECTED_SOURCE" = default ] && { [ "$SYSTEM" = debian ] || [ "$SYSTEM" = fedora ]; }; then
    export VERSION=latest NVMVERSION=0.40.3 NVMINSTALLPATH=/usr/local/nvm NODEGYPDEPENDENCIES=false NPMVERSION=none PNPMVERSION=none
    export _REMOTE_USER="$USERNAME"
    bash "$FEATURE_DIR/upstream/install.sh"
else
    region=default
    [ "$FEATURE_SELECTED_SOURCE" != china ] || region=china
    bash "$FEATURE_DIR/$region-$SYSTEM.sh"
fi
for name in node npm npx; do
    binary="/usr/local/nvm/current/bin/$name"
    [ -e "$binary" ] || continue
    target="/usr/local/bin/$(basename "$binary")"
    [ "$(readlink -f "$binary")" = "$(readlink -f "$target")" ] || ln -sfn "$binary" "$target"
done
