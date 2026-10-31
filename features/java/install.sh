#!/usr/bin/env bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HELPER="$FEATURE_DIR/../_common/source-selection.sh"
[ -f "$SOURCE_HELPER" ] || SOURCE_HELPER="$FEATURE_DIR/source-selection.sh"
. "$SOURCE_HELPER"
resolve_feature_source JAVA_SOURCE
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
# Each distribution adapter installs its package and records the canonical JDK home.
JDK_HOME_FILE=$(mktemp)
export JDK_HOME_FILE
trap 'rm -f "$JDK_HOME_FILE"' EXIT
bash "$FEATURE_DIR/$installer"
java_home=$(cat "$JDK_HOME_FILE")
[ -n "$java_home" ] && [ -x "$java_home/bin/java" ] && [ -x "$java_home/bin/javac" ] || {
    echo "Installer did not return a usable JDK home: $installer" >&2
    exit 1
}
mkdir -p /usr/local/java
ln -sfn "$java_home" /usr/local/java/current
