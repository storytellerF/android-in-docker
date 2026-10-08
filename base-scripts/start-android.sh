#!/bin/bash
set -euo pipefail

ANDROID_RUNTIME_HOME="${HOME:-/home/$(id -un)}"
PROFILE_DIR="${ANDROID_PROFILE_DIR:-${ANDROID_RUNTIME_HOME}/android-profiles}"
ANDROID_PROFILE="${ANDROID_PROFILE:-${PROFILE_DIR}/android.profile}"

"${ANDROID_RUNTIME_HOME}/bin/install-sdk.sh"
"${ANDROID_RUNTIME_HOME}/bin/create-avd.sh" "$ANDROID_PROFILE"
# Forward Supervisor signals to the emulator startup wrapper.
exec "${ANDROID_RUNTIME_HOME}/bin/start-avd.sh" "$ANDROID_PROFILE"
