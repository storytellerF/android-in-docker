#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-/home/$(id -un)}"
PROFILE_DIR="${ANDROID_PROFILE_DIR:-${HOME_DIR}/android-profiles}"
PROFILE_ARG="${1:-}"
if [ -n "$PROFILE_ARG" ]; then
    ANDROID_PROFILE="$PROFILE_ARG"
else
    ANDROID_PROFILE="${ANDROID_PROFILE:-${PROFILE_DIR}/android.profile}"
fi
LOADED_PROFILE="$ANDROID_PROFILE"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/profile-utils.sh"

build_emulator_args() {
    local -n args_ref="$1"

    args_ref=(-avd "$AVD_NAME")
    append_args_from_env args_ref EMULATOR -
}

shutdown() {
    echo "Shutting down emulator gracefully..."
    if kill -0 "$EMULATOR_PID" 2>/dev/null; then
        adb emu kill
        wait "$EMULATOR_PID" || true
    fi
    echo "Emulator shut down."
    exit 0
}

load_profile "$ANDROID_PROFILE"

assert_profile_keys_absent "$LOADED_PROFILE" ARCH ABI AVD_ARCH AVD_ABI AVDMANAGER_ABI AVDMANAGER_ARCH EMULATOR_ABI EMULATOR_ARCH
require_profile_value AVD_NAME

echo "Starting emulator..."

export DISPLAY="${EMULATOR_DISPLAY:-:1}"

rm -f ~/.android/avd/*.avd/*.lock

declare -a emulator_args
build_emulator_args emulator_args
echo "Emulator command: emulator ${emulator_args[*]}"

emulator "${emulator_args[@]}" &

EMULATOR_PID=$!

trap shutdown SIGTERM SIGINT

wait "$EMULATOR_PID"
echo "Emulator process has exited."
