#!/usr/bin/env bash
# Copied into each Feature so independently packaged Features stay self-contained.
resolve_feature_source() {
    local feature_env=$1
    local requested="${SOURCE:-auto}"
    if [ "$requested" = auto ]; then
        requested="${!feature_env:-${FEATURE_SOURCE:-auto}}"
    fi
    if [ "$requested" = auto ] && [ "${CHINAMIRROR:-false}" = true ]; then
        requested=china
    fi
    if [ "$requested" = auto ]; then
        local timezone="${TIMEZONE:-${TZ:-}}"
        if [ -z "$timezone" ] && [ -r /etc/timezone ]; then
            timezone=$(cat /etc/timezone)
        fi
        if [ -z "$timezone" ]; then
            timezone=$(readlink /etc/localtime 2>/dev/null || true)
            timezone="${timezone##*/zoneinfo/}"
        fi
        timezone="${timezone#:}"
        timezone="${timezone##*/zoneinfo/}"
        case "$timezone" in
            Asia/Shanghai|Asia/Chongqing|Asia/Chungking|Asia/Harbin|Asia/Urumqi|PRC) requested=china ;;
            *) requested=default ;;
        esac
    fi
    case "$requested" in
        default|china) FEATURE_SELECTED_SOURCE="$requested" ;;
        *) echo "Invalid Feature source '$requested': expected auto, default, or china" >&2; return 1 ;;
    esac
}
