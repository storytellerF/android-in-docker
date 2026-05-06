#!/bin/bash
set -euo pipefail

echo "Running SDK installation script..."
~/bin/install-sdk.sh
echo "SDK setup finished."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME:-/home/$(id -un)}"
PROFILE_DIR="${ANDROID_PROFILE_DIR:-${HOME_DIR}/android-profiles}"
ANDROID_PROFILE="${ANDROID_PROFILE:-${PROFILE_DIR}/android.profile}"

"${HOME_DIR}/bin/create-avd.sh" "$ANDROID_PROFILE"
"${HOME_DIR}/bin/start-avd.sh" "$ANDROID_PROFILE"
