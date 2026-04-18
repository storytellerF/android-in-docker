#!/bin/bash
set -euo pipefail

echo "Running SDK installation script..."
~/bin/install-sdk.sh
echo "SDK setup finished."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-/home/$(id -un)}"
PROFILE_DIR="${ANDROID_PROFILE_DIR:-${HOME_DIR}/android-profiles}"
AVD_CREATE_PROFILE="${AVD_CREATE_PROFILE:-${PROFILE_DIR}/avd-create.profile}"

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/profile-utils.sh"

validate_system_image_arch() {
    local arch="$1"
    local expected_abi=""

    case "$arch" in
        x86_64)
            expected_abi="x86_64"
            ;;
        aarch64)
            expected_abi="arm64-v8a"
            ;;
        *)
            echo "Warning: Unknown architecture $arch. Skipping SYS_IMG_PKG ABI validation."
            return 0
            ;;
    esac

    if [[ "$SYS_IMG_PKG" == *";x86_64" ]] || [[ "$SYS_IMG_PKG" == *";arm64-v8a" ]] || [[ "$SYS_IMG_PKG" == *";armeabi-v7a" ]]; then
        echo "Error: SYS_IMG_PKG in profile must not include an ABI suffix; use the package prefix only: ${SYS_IMG_PKG}" >&2
        return 1
    fi

    RESOLVED_SYS_IMG_PKG="${SYS_IMG_PKG};${expected_abi}"
}

build_avdmanager_args() {
    local -n args_ref="$1"

    args_ref=(
        create
        avd
        --name "$AVD_NAME"
        --package "$RESOLVED_SYS_IMG_PKG"
    )

    append_flag_arg args_ref "${AVDMANAGER_FORCE:-false}" --force
    append_value_arg args_ref "${AVDMANAGER_DEVICE:-}" --device
    append_value_arg args_ref "${AVDMANAGER_PATH:-}" --path
    append_value_arg args_ref "${AVDMANAGER_TAG:-}" --tag
    append_value_arg args_ref "${AVDMANAGER_SDCARD:-}" --sdcard
}

load_profile "$AVD_CREATE_PROFILE"
assert_profile_keys_absent "$AVD_CREATE_PROFILE" ARCH ABI AVD_ARCH AVD_ABI AVDMANAGER_ABI AVDMANAGER_ARCH EMULATOR_ABI EMULATOR_ARCH
require_profile_value AVD_NAME
require_profile_value SYS_IMG_PKG

ARCH="$(uname -m)"
echo "Detected architecture: $ARCH"
validate_system_image_arch "$ARCH"

echo "AVD_NAME: $AVD_NAME"
echo "System image package prefix: $SYS_IMG_PKG"
echo "Resolved system image package: $RESOLVED_SYS_IMG_PKG"
sdkmanager "$RESOLVED_SYS_IMG_PKG"

if ! avdmanager list avd | grep -q "Name: $AVD_NAME"; then
    declare -a avdmanager_args

    echo "Creating AVD: $AVD_NAME"
    build_avdmanager_args avdmanager_args
    echo "avdmanager command: avdmanager ${avdmanager_args[*]}"

    if is_true "${AVDMANAGER_USE_CUSTOM_HARDWARE_PROFILE:-false}"; then
        printf 'yes\n' | avdmanager "${avdmanager_args[@]}"
    else
        printf 'no\n' | avdmanager "${avdmanager_args[@]}"
    fi
else
    echo "AVD '$AVD_NAME' already exists."
fi

"${HOME_DIR}/bin/start-avd.sh" "$AVD_NAME"
