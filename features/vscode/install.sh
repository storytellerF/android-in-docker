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
[ -f "$FEATURE_DIR/$SYSTEM.sh" ] || { echo "Unsupported distribution for this Feature: $SYSTEM" >&2; exit 1; }
bash "$FEATURE_DIR/$SYSTEM.sh"
