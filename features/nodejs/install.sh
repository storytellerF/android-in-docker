#!/usr/bin/env bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HELPER="$FEATURE_DIR/../_common/source-selection.sh"
[ -f "$SOURCE_HELPER" ] || SOURCE_HELPER="$FEATURE_DIR/source-selection.sh"
. "$SOURCE_HELPER"
resolve_feature_source NODEJS_SOURCE
SYSTEM_ID=$( . /etc/os-release; printf '%s' "$ID")
case "$SYSTEM_ID" in
    debian|ubuntu) SYSTEM=debian ;;
    alpine|arch|fedora) SYSTEM="$SYSTEM_ID" ;;
    *) echo "Unsupported distribution: $SYSTEM_ID" >&2; exit 1 ;;
esac
if [ -n "${REGISTRY:-}" ]; then
    export NPM_CONFIG_REGISTRY="$REGISTRY"
fi
if [ "$SYSTEM" = alpine ]; then
    bash "$FEATURE_DIR/default-alpine.sh"
else
    if [ "$FEATURE_SELECTED_SOURCE" = china ]; then
        export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node
    fi
    bash "$FEATURE_DIR/install-nvm.sh" "$SYSTEM"
fi
for name in node npm npx; do
    binary="/usr/local/nvm/current/bin/$name"
    [ -e "$binary" ] || continue
    target="/usr/local/bin/$(basename "$binary")"
    [ "$(readlink -f "$binary")" = "$(readlink -f "$target")" ] || ln -sfn "$binary" "$target"
done

# Configure npm after Node.js is available, using the same source selection.
NPM_REGISTRY="${REGISTRY:-}"
if [ "$FEATURE_SELECTED_SOURCE" = china ]; then
    NPM_REGISTRY="${NPM_REGISTRY:-https://mirrors.cloud.tencent.com/npm/}"
    if [ -z "${REGISTRY:-}" ]; then
        NPM_CONFIG_REGISTRY=https://registry.npmmirror.com npm install -g nrm
    fi
fi
if [ -n "$NPM_REGISTRY" ]; then
    export NPM_REGISTRY
    bash "$FEATURE_DIR/configure-npm.sh"
fi
