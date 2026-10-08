#!/usr/bin/env bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/source-selection.sh"
resolve_feature_source JAVA_SOURCE
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
OPENJDK_VERSION="${VERSION:-21}"
case "${PROVIDER:-openjdk}" in openjdk|temurin) ;; *) echo "Invalid Java provider" >&2; exit 1 ;; esac
[[ "$OPENJDK_VERSION" =~ ^[0-9]+$ ]] || exit 1
case "$(uname -m)" in aarch64|arm64) TEMURIN_ARCH=aarch64 ;; *) TEMURIN_ARCH=x64 ;; esac
export OPENJDK_VERSION TEMURIN_ARCH
installer="${PROVIDER:-openjdk}-$SYSTEM.sh"
if [ "${PROVIDER:-openjdk}" = temurin ] && [ "$FEATURE_SELECTED_SOURCE" = china ] && [ -f "$FEATURE_DIR/temurin-china-$SYSTEM.sh" ]; then
    installer="temurin-china-$SYSTEM.sh"
fi
bash "$FEATURE_DIR/$installer"
if [ "$SYSTEM" = arch ] && [ "${PROVIDER:-openjdk}" = temurin ]; then
    for binary in /opt/temurin-${OPENJDK_VERSION}/bin/*; do ln -sfn "$binary" "/usr/local/bin/$(basename "$binary")"; done
fi
mkdir -p /usr/local/java
java_home=$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")
ln -sfn "$java_home" /usr/local/java/current
