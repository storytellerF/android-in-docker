#!/usr/bin/env bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_HELPER="$FEATURE_DIR/../_common/source-selection.sh"
[ -f "$SOURCE_HELPER" ] || SOURCE_HELPER="$FEATURE_DIR/source-selection.sh"
. "$SOURCE_HELPER"
resolve_feature_source PYTHON_SOURCE
SYSTEM_ID=$( . /etc/os-release; printf '%s' "$ID")
case "$SYSTEM_ID" in
    debian|ubuntu) SYSTEM=debian ;;
    alpine|arch|fedora) SYSTEM="$SYSTEM_ID" ;;
    *) echo "Unsupported distribution: $SYSTEM_ID" >&2; exit 1 ;;
esac
requested_index="${INDEXURL:-${PYTHON_INDEX_URL:-${PIP_INDEX_URL:-}}}"
export PIP_INDEX_URL=https://pypi.org/simple
if [ "$FEATURE_SELECTED_SOURCE" = china ]; then
    export PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple
fi
if [ -n "$requested_index" ]; then
    case "$requested_index" in https://*) PIP_INDEX_URL="$requested_index" ;; *) echo 'Python index must use HTTPS' >&2; exit 1 ;; esac
fi
bash "$FEATURE_DIR/$SYSTEM.sh"
# Keep the public runtime paths stable while using distribution-managed packages.
mkdir -p /usr/local/python/current/bin /usr/local/py-utils/bin
for name in python python3 pip pip3; do
    case "$name" in python*) binary=/usr/bin/python3 ;; *) binary=/usr/bin/pip3 ;; esac
    ln -sfn "$binary" "/usr/local/python/current/bin/$name"
done
ln -sfn /usr/bin/pipx /usr/local/py-utils/bin/pipx
REMOTE_USER="${_REMOTE_USER:?_REMOTE_USER must identify an existing user}"
chown "$(id -u "$REMOTE_USER"):$(id -g "$REMOTE_USER")" /usr/local/py-utils /usr/local/py-utils/bin
# Persist the selected index for root, the remote user, and virtual environments.
python3 -m pip config --global set global.index-url "$PIP_INDEX_URL"
