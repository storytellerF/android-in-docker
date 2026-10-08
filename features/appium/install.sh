#!/usr/bin/env bash
set -euo pipefail
REMOTE_USER="${_REMOTE_USER:?Dev Container remote user is required}"
REMOTE_HOME="${_REMOTE_USER_HOME:-$(getent passwd "$REMOTE_USER" | cut -d: -f6)}"
[ -n "$REMOTE_HOME" ] || { echo 'Remote user home is missing' >&2; exit 1; }
command -v node >/dev/null && command -v npm >/dev/null || {
    echo 'Select a Node.js Feature before Appium.' >&2
    exit 1
}
if [ "$REMOTE_USER" != root ] && ! command -v sudo >/dev/null; then
    system=$( . /etc/os-release; printf '%s' "$ID")
    case "$system" in
        debian|ubuntu) apt-get update && apt-get install -y --no-install-recommends sudo && rm -rf /var/lib/apt/lists/* ;;
        alpine) apk add --no-cache sudo ;;
        arch) pacman -Sy --noconfirm --needed sudo && pacman -Scc --noconfirm ;;
        fedora) dnf install -y sudo && dnf clean all ;;
        *) echo "Unsupported distribution: $system" >&2; exit 1 ;;
    esac
fi
# Expose Node and Appium to services and sudo without requiring shell initialization.
node_binary=$(command -v node)
[ "$node_binary" = /usr/local/bin/node ] || ln -sfn "$node_binary" /usr/local/bin/node
npm install -g "appium@${VERSION:-3.3.0}"
appium_binary="$(npm prefix -g)/bin/appium"
[ -x "$appium_binary" ] || { echo 'Appium executable not found' >&2; exit 1; }
[ "$appium_binary" = /usr/local/bin/appium ] || ln -sfn "$appium_binary" /usr/local/bin/appium
run_appium() {
    local environment=(HOME="$REMOTE_HOME" PATH="$PATH")
    if [ -n "${NODE_EXTRA_CA_CERTS:-}" ]; then
        environment+=(NODE_EXTRA_CA_CERTS="$NODE_EXTRA_CA_CERTS")
    fi
    if [ "$REMOTE_USER" = root ]; then
        env "${environment[@]}" "$appium_binary" "$@"
    else
        sudo -u "$REMOTE_USER" -H -- env "${environment[@]}" "$appium_binary" "$@"
    fi
}
run_appium driver install uiautomator2
run_appium plugin install storage
run_appium plugin install inspector
