#!/usr/bin/env bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_ID=$( . /etc/os-release; printf '%s' "$ID")
case "$SYSTEM_ID" in
    debian|ubuntu) SYSTEM=debian ;;
    alpine|arch|fedora) SYSTEM="$SYSTEM_ID" ;;
    *) echo "Unsupported distribution: $SYSTEM_ID" >&2; exit 1 ;;
esac
[ -f "$FEATURE_DIR/$SYSTEM.sh" ] || { echo "Unsupported distribution for this Feature: $SYSTEM" >&2; exit 1; }
bash "$FEATURE_DIR/$SYSTEM.sh"
