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
bash "$FEATURE_DIR/$SYSTEM.sh"
sed -i 's/^#*PubkeyAuthentication .*/PubkeyAuthentication yes/; s/^#*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
mkdir -p /run/sshd
install -d -o "$USER_UID" -g "$USER_GID" "$USER_HOME/bin" "$USER_HOME/supervisor/conf.d"
install -o "$USER_UID" -g "$USER_GID" -m 755 "$FEATURE_DIR/start-ssh.sh" "$USER_HOME/bin/start-ssh.sh"
install -o "$USER_UID" -g "$USER_GID" -m 644 "$FEATURE_DIR/ssh.supervisord.conf" "$USER_HOME/supervisor/conf.d/ssh.supervisord.conf"
