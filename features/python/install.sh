#!/usr/bin/env bash
set -euo pipefail
FEATURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$FEATURE_DIR/source-selection.sh"
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
if [ "$SYSTEM" = debian ] || [ "$SYSTEM" = fedora ]; then
    export VERSION=os-provided INSTALLTOOLS=true TOOLSTOINSTALL=virtualenv INSTALLJUPYTERLAB=false
    bash "$FEATURE_DIR/upstream/install.sh"
else
    bash "$FEATURE_DIR/$SYSTEM.sh"
fi
# Persist the selected index for root, the remote user, and virtual environments.
python3 -m pip config --global set global.index-url "$PIP_INDEX_URL"
