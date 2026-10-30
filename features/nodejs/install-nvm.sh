#!/usr/bin/env bash
set -euo pipefail
SYSTEM="$1"
REMOTE_USER="${_REMOTE_USER:?_REMOTE_USER must identify an existing user}"
id "$REMOTE_USER" >/dev/null
export NVM_DIR=/usr/local/nvm
export PATH="$NVM_DIR/current/bin:$PATH"
NVM_VERSION="${NVM_VERSION:-v0.40.3}"
case "$SYSTEM" in
    debian)
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends bash ca-certificates curl libatomic1 tar xz-utils
        rm -rf /var/lib/apt/lists/*
        ;;
    fedora)
        dnf install -y bash ca-certificates curl libatomic tar xz
        dnf clean all
        ;;
    arch)
        pacman -Sy --noconfirm --needed bash ca-certificates curl gcc-libs tar xz
        pacman -Scc --noconfirm
        ;;
    *) echo "Unsupported NVM distribution: $SYSTEM" >&2; exit 1 ;;
esac
installer=$(mktemp)
trap 'rm -f "$installer"' EXIT
mkdir -p "$NVM_DIR"
curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" -o "$installer"
PROFILE=/dev/null bash "$installer"
chown -R "$(id -u "$REMOTE_USER"):$(id -g "$REMOTE_USER")" "$NVM_DIR"
# Install as the selected user so subsequent NVM/npm operations need no root access.
su -s /bin/bash "$REMOTE_USER" -c '
    set -eo pipefail
    . "$NVM_DIR/nvm.sh"
    nvm install node
    nvm alias default node
    ln -sfn "$NVM_DIR/versions/node/$(nvm version default)" "$NVM_DIR/current"
    if command -v corepack >/dev/null 2>&1; then
        corepack enable --install-directory "$NVM_DIR/current/bin"
    fi
    node --version
    npm --version
'
cat > /etc/profile.d/nvm.sh <<'PROFILE'
export NVM_DIR=/usr/local/nvm
[ ! -s "$NVM_DIR/nvm.sh" ] || . "$NVM_DIR/nvm.sh"
PROFILE
bashrc=/etc/bash.bashrc
[ "$SYSTEM" != fedora ] || bashrc=/etc/bashrc
if ! grep -qF '. /etc/profile.d/nvm.sh' "$bashrc" 2>/dev/null; then
    printf '\n. /etc/profile.d/nvm.sh\n' >> "$bashrc"
fi
