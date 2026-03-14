#!/bin/bash

AVD_NAME=${1}

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

echo "Starting emulator..."

# Set the display for the emulator to run within the VNC session
export DISPLAY=:1

rm -f ~/.android/avd/*.avd/*.lock

# Start the emulator in the background
emulator -avd "$AVD_NAME" \
    -no-snapshot \
    -no-audio \
    -no-boot-anim \
    -gpu swiftshader_indirect \
    -show-kernel \
    -verbose &

# Get the PID of the emulator process
EMULATOR_PID=$!

# Trap TERM and INT signals to trigger shutdown
trap shutdown SIGTERM SIGINT

# Wait for the emulator process to exit. The trap will interrupt this wait.
wait "$EMULATOR_PID"
echo "Emulator process has exited."