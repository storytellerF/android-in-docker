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
    debian)
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends bash ca-certificates wget unzip sudo
        rm -rf /var/lib/apt/lists/*
        ;;
    alpine) apk add --no-cache bash ca-certificates wget unzip sudo ;;
    arch) pacman -Sy --noconfirm --needed bash ca-certificates wget unzip sudo && pacman -Scc --noconfirm ;;
    fedora) dnf install -y bash ca-certificates wget unzip sudo && dnf clean all ;;
esac
install -d -o "$USER_UID" -g "$USER_GID" "$USER_HOME/bin" "$USER_HOME/android-profiles" "$USER_HOME/supervisor/conf.d"
cp -R "$FEATURE_DIR/profile-scripts/." "$USER_HOME/bin/"
cp -R "$FEATURE_DIR/profiles/." "$USER_HOME/android-profiles/"
cp "$FEATURE_DIR/"*.sh "$USER_HOME/bin/"
rm -f "$USER_HOME/bin/install.sh"
install -m 644 "$FEATURE_DIR/android.supervisord.conf" "$USER_HOME/supervisor/conf.d/android.supervisord.conf"
chmod +x "$USER_HOME/bin/"*.sh
chown -R "$USER_UID:$USER_GID" "$USER_HOME/bin" "$USER_HOME/android-profiles" "$USER_HOME/supervisor/conf.d"
# Keep Node available to sudo-launched npm and preserve the previous NVM path.
node_binary=$(command -v node)
[ "$node_binary" = /usr/local/bin/node ] || ln -sfn "$node_binary" /usr/local/bin/node
if [ ! -e /usr/local/nvm ] && [ -d /usr/local/share/nvm ]; then
    ln -s /usr/local/share/nvm /usr/local/nvm
fi
sudo -u "$USERNAME" -H -- env HOME="$USER_HOME" PATH="$PATH" NVM_DIR="${NVM_DIR:-/usr/local/nvm}" bash "$USER_HOME/bin/install-appium.sh"
