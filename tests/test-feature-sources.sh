#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for feature in java nodejs python; do
    helper="$PWD/features/$feature/source-selection.sh"
    check() {
        local expected=$1
        shift
        env -u SOURCE -u FEATURE_SOURCE -u JAVA_SOURCE -u NODEJS_SOURCE -u PYTHON_SOURCE -u TIMEZONE -u TZ "$@" bash -c '
            . "$1"
            resolve_feature_source "$2"
            test "$FEATURE_SELECTED_SOURCE" = "$3"
        ' bash "$helper" "${feature^^}_SOURCE" "$expected"
    }
    check china TZ=Asia/Shanghai
    check default TZ=Etc/UTC
    check default SOURCE=default TZ=Asia/Shanghai
    check china FEATURE_SOURCE=china TZ=Etc/UTC
    check default FEATURE_SOURCE=china "${feature^^}_SOURCE=default" TZ=Asia/Shanghai
    check china TIMEZONE=Asia/Shanghai TZ=Etc/UTC
    if check default SOURCE=invalid 2>/dev/null; then
        echo 'Invalid source unexpectedly accepted' >&2
        exit 1
    fi
done
echo 'Feature source options, environment priority, timezone detection passed.'
