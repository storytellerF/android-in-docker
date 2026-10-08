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
set -eu; \
    add_group_for_gid() { \
        gid="$1"; \
        fallback_name="$2"; \
        group_name="$(awk -F: -v gid="$gid" '$3 == gid {print $1; exit}' /etc/group)"; \
        if [ -z "$group_name" ]; then \
            group_name="$fallback_name"; \
            if command -v groupadd >/dev/null 2>&1; then \
                groupadd -g "$gid" "$group_name"; \
            else \
                addgroup -g "$gid" "$group_name"; \
            fi; \
        fi; \
        if command -v usermod >/dev/null 2>&1; then \
            usermod -aG "$group_name" "$USERNAME"; \
        else \
            adduser "$USERNAME" "$group_name"; \
        fi; \
    }; \
    add_group_for_gid 992 hostkvm1; \
    add_group_for_gid 993 hostkvm2
