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

has_any_var_with_prefix() {
    local var_prefix="$1"
    local -a vars

    mapfile -t vars < <(compgen -A variable "$var_prefix")
    [ "${#vars[@]}" -gt 0 ]
}

append_args_from_env() {
    local -n target_ref="$1"
    local prefix="$2"
    local dash="$3"
    shift 3
    local -a excludes=("$@")

    local -a flag_vars value_vars
    local var name_raw name value should_skip

    mapfile -t flag_vars < <(compgen -A variable "${prefix}_FLAG_")
    for var in "${flag_vars[@]}"; do
        name_raw="${var#${prefix}_FLAG_}"
        should_skip=false
        for name in "${excludes[@]}"; do
            if [ "$name_raw" = "$name" ]; then
                should_skip=true
                break
            fi
        done
        if [ "$should_skip" = true ]; then
            continue
        fi

        value="${!var-}"
        if is_true "$value"; then
            name="${name_raw,,}"
            name="${name//_/-}"
            target_ref+=("${dash}${name}")
        fi
    done

    mapfile -t value_vars < <(compgen -A variable "${prefix}_VALUE_")
    for var in "${value_vars[@]}"; do
        name_raw="${var#${prefix}_VALUE_}"
        should_skip=false
        for name in "${excludes[@]}"; do
            if [ "$name_raw" = "$name" ]; then
                should_skip=true
                break
            fi
        done
        if [ "$should_skip" = true ]; then
            continue
        fi

        value="${!var-}"
        if [ -n "$value" ]; then
            name="${name_raw,,}"
            name="${name//_/-}"
            target_ref+=("${dash}${name}" "$value")
        fi
    done
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
