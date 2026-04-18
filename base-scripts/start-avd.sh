#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-/home/$(id -un)}"
PROFILE_DIR="${ANDROID_PROFILE_DIR:-${HOME_DIR}/android-profiles}"
EMULATOR_START_PROFILE="${EMULATOR_START_PROFILE:-${PROFILE_DIR}/emulator-start.profile}"
AVD_NAME="${1:-}"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/profile-utils.sh"

build_emulator_args() {
    local -n args_ref="$1"

    args_ref=(-avd "$AVD_NAME")

    append_flag_arg args_ref "${EMULATOR_ACCEL_OFF:-false}" -accel-off
    append_flag_arg args_ref "${EMULATOR_DELAY_ADB:-false}" -delay-adb
    append_flag_arg args_ref "${EMULATOR_NO_AUDIO:-false}" -no-audio
    append_flag_arg args_ref "${EMULATOR_NO_BOOT_ANIM:-false}" -no-boot-anim
    append_flag_arg args_ref "${EMULATOR_NO_JNI:-false}" -nojni
    append_flag_arg args_ref "${EMULATOR_NO_SNAPSHOT:-false}" -no-snapshot
    append_flag_arg args_ref "${EMULATOR_NO_SNAPSHOT_LOAD:-false}" -no-snapshot-load
    append_flag_arg args_ref "${EMULATOR_NO_SNAPSHOT_SAVE:-false}" -no-snapshot-save
    append_flag_arg args_ref "${EMULATOR_NO_WINDOW:-false}" -no-window
    append_flag_arg args_ref "${EMULATOR_NETFAST:-false}" -netfast
    append_flag_arg args_ref "${EMULATOR_READ_ONLY:-false}" -read-only
    append_flag_arg args_ref "${EMULATOR_SHOW_KERNEL:-false}" -show-kernel
    append_flag_arg args_ref "${EMULATOR_VERBOSE:-false}" -verbose
    append_flag_arg args_ref "${EMULATOR_WIPE_DATA:-false}" -wipe-data

    append_value_arg args_ref "${EMULATOR_ACCEL:-}" -accel
    append_value_arg args_ref "${EMULATOR_CAMERA_BACK:-}" -camera-back
    append_value_arg args_ref "${EMULATOR_CAMERA_FRONT:-}" -camera-front
    append_value_arg args_ref "${EMULATOR_CORES:-}" -cores
    append_value_arg args_ref "${EMULATOR_DATA:-}" -data
    append_value_arg args_ref "${EMULATOR_DNS_SERVER:-}" -dns-server
    append_value_arg args_ref "${EMULATOR_GPU:-}" -gpu
    append_value_arg args_ref "${EMULATOR_GRPC:-}" -grpc
    append_value_arg args_ref "${EMULATOR_HTTP_PROXY:-}" -http-proxy
    append_value_arg args_ref "${EMULATOR_MEMORY:-}" -memory
    append_value_arg args_ref "${EMULATOR_NETDELAY:-}" -netdelay
    append_value_arg args_ref "${EMULATOR_NETSPEED:-}" -netspeed
    append_value_arg args_ref "${EMULATOR_PORT:-}" -port
    append_value_arg args_ref "${EMULATOR_PORTS:-}" -ports
    append_value_arg args_ref "${EMULATOR_PROP:-}" -prop
    append_value_arg args_ref "${EMULATOR_REPORT_CONSOLE:-}" -report-console
    append_value_arg args_ref "${EMULATOR_SHELL_SERIAL:-}" -shell-serial
    append_value_arg args_ref "${EMULATOR_SKIN:-}" -skin
    append_value_arg args_ref "${EMULATOR_TIMEZONE:-}" -timezone
}

# Graceful shutdown
shutdown() {
    echo "Shutting down emulator gracefully..."
    # Use adb to kill the emulator process
    # Wait for the process if it's still running, skip if already terminated
    if kill -0 "$EMULATOR_PID" 2>/dev/null; then
        adb emu kill
        wait "$EMULATOR_PID" || true
    fi
    echo "Emulator shut down."
    exit 0
}

load_profile "$EMULATOR_START_PROFILE"
assert_profile_keys_absent "$EMULATOR_START_PROFILE" ARCH ABI AVD_ARCH AVD_ABI AVDMANAGER_ABI AVDMANAGER_ARCH EMULATOR_ABI EMULATOR_ARCH

if [ -z "$AVD_NAME" ]; then
    echo "Error: missing AVD name." >&2
    exit 1
fi

echo "Starting emulator..."

export DISPLAY="${EMULATOR_DISPLAY:-:1}"

rm -f ~/.android/avd/*.avd/*.lock

declare -a emulator_args
build_emulator_args emulator_args
echo "Emulator command: emulator ${emulator_args[*]}"

emulator "${emulator_args[@]}" &

# Get the PID of the emulator process
EMULATOR_PID=$!

# Trap TERM and INT signals to trigger shutdown
trap shutdown SIGTERM SIGINT

# Wait for the emulator process to exit. The trap will interrupt this wait.
wait "$EMULATOR_PID"
echo "Emulator process has exited."
