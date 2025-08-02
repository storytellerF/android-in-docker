#!/bin/bash
set -e

# Graceful shutdown
shutdown() {
    echo "Shutting down emulator gracefully..."
    # Use adb to kill the emulator process
    adb -s emulator-5554 emu kill
    wait "$EMULATOR_PID"
    echo "Emulator shut down."
    exit 0
}

# Trap TERM and INT signals to trigger shutdown
trap shutdown SIGTERM SIGINT

AVD_NAME="android-30"
SYS_IMG="system-images;android-30;google_apis;x86_64"

# Check if AVD exists
if ! avdmanager list avd | grep -q "Name: $AVD_NAME"; then
    echo "Creating AVD: $AVD_NAME"
    # Create a new AVD
    echo "no" | avdmanager create avd --force --name "$AVD_NAME" --package "$SYS_IMG" --device "pixel"
else
    echo "AVD '$AVD_NAME' already exists."
fi

echo "Starting emulator..."

# Set the display for the emulator to run within the VNC session
export DISPLAY=:1

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

# Wait for the emulator process to exit. The trap will interrupt this wait.
wait "$EMULATOR_PID"
