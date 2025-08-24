#!/bin/bash
set -e

# First, ensure the SDK is installed and ready.
echo "Running SDK installation script..."
/usr/local/bin/install-sdk.sh
echo "SDK setup finished."

# Graceful shutdown
shutdown() {
    echo "Shutting down emulator gracefully..."
    # Use adb to kill the emulator process
    adb -s emulator-5554 emu kill
    wait "$EMULATOR_PID"
    echo "Emulator shut down."
    exit 0
}

AVD_NAME="android-35"
SYS_IMG_PKG="system-images;android-35;google_apis;x86_64"
if ! sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --list_installed | grep -q "${SYS_IMG_PKG}"; then
    echo "Installing system image (${SYS_IMG_PKG})..."
    sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "${SYS_IMG_PKG}"
else
    echo "System image (${SYS_IMG_PKG}) already installed."
fi

# Check if AVD exists
if ! avdmanager list avd | grep -q "Name: $AVD_NAME"; then
    echo "Creating AVD: $AVD_NAME"
    # Create a new AVD
    echo "no" | avdmanager create avd --force --name "$AVD_NAME" --package "$SYS_IMG_PKG" --device "pixel"
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

# Trap TERM and INT signals to trigger shutdown
trap shutdown SIGTERM SIGINT

# Wait for the emulator process to exit. The trap will interrupt this wait.
wait "$EMULATOR_PID"
