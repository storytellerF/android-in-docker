#!/bin/bash
set -e

# Set Android SDK root
export ANDROID_SDK_ROOT=/opt/android/sdk
export PATH=$PATH:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator

# Check if command line tools are already installed
if [ -d "${ANDROID_SDK_ROOT}/cmdline-tools" ]; then
    echo "Android SDK command-line tools already found. Skipping download."
else
    echo "Android SDK command-line tools not found. Downloading..."
    # Ensure the base directory exists and we have permissions
    mkdir -p ${ANDROID_SDK_ROOT}
    chown -R root:root /opt/android

    wget -O sdk-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    unzip sdk-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest
    rm sdk-tools.zip
    echo "Android SDK command-line tools installed."
fi

# Accept all licenses silently before attempting to download components
yes | sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --licenses > /dev/null

# --- Install platform-tools if not present ---
if [ ! -d "${ANDROID_SDK_ROOT}/platform-tools" ]; then
    echo "Installing platform-tools..."
    sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "platform-tools"
else
    echo "platform-tools already installed."
fi

# --- Install emulator if not present ---
if [ ! -d "${ANDROID_SDK_ROOT}/emulator" ]; then
    echo "Installing emulator..."
    sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "emulator"
else
    echo "emulator already installed."
fi

echo "Android SDK setup is complete."
