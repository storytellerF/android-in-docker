#!/usr/bin/env bash
set -euo pipefail
export NVM_DIR=/usr/local/nvm

export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node

export PATH=${NVM_DIR}/current/bin:${PATH}

apk add --no-cache bash ca-certificates curl nodejs npm tar xz

update-ca-certificates || true

mkdir -p "$NVM_DIR" \
    && node_prefix="$(dirname "$(dirname "$(readlink -f "$(command -v node)")")")" \
    && ln -sfn "$node_prefix" "$NVM_DIR/current" \
    && printf 'export NVM_DIR=%s\n' "$NVM_DIR" > /etc/profile.d/nvm.sh \
    && printf '\nexport NVM_DIR=%s\n' "$NVM_DIR" >> /etc/profile
