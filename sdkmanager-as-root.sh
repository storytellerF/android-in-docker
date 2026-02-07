#!/bin/bash

# 当前脚本在ubuntu上执行，所以已经定义过ANDROID_SDK_ROOT

# Accept Android SDK components as arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <component1> <component2> ..."
    echo "Example: $0 'platforms;android-33' 'build-tools;33.0.0'"
    exit 1
fi

# Get ANDROID_SDK_ROOT from environment
if [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "Error: ANDROID_SDK_ROOT environment variable is not set"
    exit 1
fi

echo "Using ANDROID_SDK_ROOT: $ANDROID_SDK_ROOT"

sudo mkdir -p ${ANDROID_SDK_ROOT}
sudo chown -R root:root ${ANDROID_SDK_ROOT}
sudo chmod -R 755 ${ANDROID_SDK_ROOT}

sudo "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_SDK_ROOT" "$@"

echo "sdkmanager complete"