#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin"
for name in install-sdk create-avd start-avd; do
    cat > "$fixture/bin/$name.sh" <<'SCRIPT'
#!/bin/bash
printf '%s:%s\n' "$(basename "$0" .sh)" "$*" >> "$STARTUP_LOG"
if [ "${FAIL_SDK:-false}" = true ] && [ "$(basename "$0")" = install-sdk.sh ]; then exit 7; fi
SCRIPT
    chmod +x "$fixture/bin/$name.sh"
done
export STARTUP_LOG="$fixture/steps"
HOME="$fixture" ANDROID_PROFILE="$fixture/custom profile" bash "$root/base-scripts/start-android.sh"
python3 - "$STARTUP_LOG" "$fixture/custom profile" <<'PY'
import sys
lines=open(sys.argv[1]).read().splitlines()
assert lines == ['install-sdk:', 'create-avd:'+sys.argv[2], 'start-avd:'+sys.argv[2]],lines
PY
: > "$STARTUP_LOG"
set +e
HOME="$fixture" FAIL_SDK=true bash "$root/base-scripts/start-android.sh"
result=$?
set -e
[ "$result" -eq 7 ]
[ "$(wc -l < "$STARTUP_LOG")" -eq 1 ]
echo 'SDK → AVD → emulator order and installation failure checks passed.'
