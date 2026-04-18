#!/bin/bash

set -euo pipefail

declare -gA PROFILE_LOADED_KEYS=()

trim_whitespace() {
    local value="$1"

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    printf '%s' "$value"
}

load_profile() {
    local profile_path="$1"
    local line_number=0
    local raw_line trimmed_line key raw_value parsed_value

    if [ ! -f "$profile_path" ]; then
        echo "Error: profile not found: $profile_path" >&2
        return 1
    fi

    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line_number=$((line_number + 1))
        trimmed_line=$(trim_whitespace "$raw_line")

        if [ -z "$trimmed_line" ] || [[ "$trimmed_line" == \#* ]]; then
            continue
        fi

        if [[ ! "$trimmed_line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            echo "Error: invalid profile line ${line_number} in ${profile_path}: ${raw_line}" >&2
            return 1
        fi

        key="${trimmed_line%%=*}"
        raw_value="${trimmed_line#*=}"

        if [[ "$raw_value" == *'$('* ]] || [[ "$raw_value" == *'`'* ]] || [[ "$raw_value" == *'$'* ]]; then
            echo "Error: shell expansion is not allowed in ${profile_path}:${line_number}" >&2
            return 1
        fi

        parsed_value=""
        eval "parsed_value=${raw_value}"
        printf -v "$key" '%s' "$parsed_value"
        export "$key"
        PROFILE_LOADED_KEYS["$profile_path:$key"]=1
    done < "$profile_path"
}

profile_has_key() {
    local profile_path="$1"
    local key="$2"

    [ -n "${PROFILE_LOADED_KEYS["$profile_path:$key"]+x}" ]
}

require_profile_value() {
    local key="$1"
    local value="${!key-}"

    if [ -z "$value" ]; then
        echo "Error: required profile key $key is missing or empty." >&2
        return 1
    fi
}

is_true() {
    case "${1:-}" in
        true|TRUE|yes|YES|1|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

append_flag_arg() {
    local -n target_ref="$1"
    local value="$2"
    local flag="$3"

    if is_true "$value"; then
        target_ref+=("$flag")
    fi
}

append_value_arg() {
    local -n target_ref="$1"
    local value="$2"
    local flag="$3"

    if [ -n "$value" ]; then
        target_ref+=("$flag" "$value")
    fi
}

assert_profile_keys_absent() {
    local profile_path="$1"
    shift

    local key
    for key in "$@"; do
        if profile_has_key "$profile_path" "$key"; then
            echo "Error: profile ${profile_path} must not define ${key}; architecture is detected dynamically." >&2
            return 1
        fi
    done
}
