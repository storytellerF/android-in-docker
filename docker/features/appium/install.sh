#!/usr/bin/env bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERNAME="${_REMOTE_USER:?Dev Container remote user is required}"
USER_HOME="${_REMOTE_USER_HOME:-$(getent passwd "$USERNAME" | cut -d: -f6)}"
[ -n "$USER_HOME" ] || { echo "Unknown remote user: $USERNAME" >&2; exit 1; }
SYSTEM_ID=$( . /etc/os-release; printf '%s' "$ID")
case "$SYSTEM_ID" in
    debian|ubuntu) SYSTEM=debian ;;
    alpine|arch|fedora) SYSTEM="$SYSTEM_ID" ;;
    *) echo "Unsupported distribution: $SYSTEM_ID" >&2; exit 1 ;;
esac
# Keep Node available to sudo-launched npm and preserve the previous NVM path.
node_binary=$(command -v node)
[ "$node_binary" = /usr/local/bin/node ] || ln -sfn "$node_binary" /usr/local/bin/node
if [ ! -e /usr/local/nvm ] && [ -d /usr/local/share/nvm ]; then
    ln -s /usr/local/share/nvm /usr/local/nvm
fi
sudo -u "$USERNAME" -H -- env HOME="$USER_HOME" PATH="$PATH" NVM_DIR="${NVM_DIR:-/usr/local/nvm}" bash "$USER_HOME/bin/install-appium.sh"
