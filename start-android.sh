#!/bin/bash
set -e

# First, ensure the SDK is installed and ready.
echo "Running SDK installation script..."
sudo ~/bin/install-sdk.sh
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

# Check architecture and select appropriate system image
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

# 检查是否定义了SYS_IMG_PKG，否则报出错误
if [ -z "$SYS_IMG_PKG" ]; then
    echo "Error: SYS_IMG_PKG is not defined."
    exit 1
fi

if [ "$ARCH" = "x86_64" ]; then
    if [[ "$SYS_IMG_PKG" != *"x86_64"* ]]; then
        echo "Error: Detected architecture x86_64 but SYS_IMG_PKG ($SYS_IMG_PKG) does not contain 'x86_64'."
        exit 1
    fi
elif [ "$ARCH" = "aarch64" ]; then
    if [[ "$SYS_IMG_PKG" != *"arm64-v8a"* ]]; then
        echo "Error: Detected architecture aarch64 but SYS_IMG_PKG ($SYS_IMG_PKG) does not contain 'arm64-v8a'."
        exit 1
    fi
else
    echo "Warning: Unknown architecture $ARCH. Skipping architecture check for SYS_IMG_PKG."
fi
# 通过SYS_IMG_PKG获取NAME，增加base64 的SYS_IMG_PKG 后两段的后缀，不带==
AVD_NAME=$(echo "$SYS_IMG_PKG" | cut -d';' -f2)-$(echo "$SYS_IMG_PKG" | cut -d';' -f3- | base64 | tr -d '\n' | sed 's/==$//')

sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "$SYS_IMG_PKG"

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
echo "Emulator process has exited."