#!/bin/bash
set -e

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

# Start the emulator
emulator -avd "$AVD_NAME" \
    -no-snapshot \
    -no-audio \
    -no-boot-anim \
    -gpu swiftshader_indirect \
    -show-kernel \
    -verbose
