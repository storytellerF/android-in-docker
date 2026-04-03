#!/bin/bash
set -e

# First, ensure the SDK is installed and ready.
echo "Running SDK installation script..."
~/bin/install-sdk.sh
echo "SDK setup finished."

# Check architecture and select appropriate system image
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

# 检查是否定义了SYS_IMG_PKG，否则报出错误
if [ -z "$SYS_IMG_PKG" ]; then
    echo "Error: SYS_IMG_PKG is not defined."
    exit 0
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
AVD_NAME=$(echo "$SYS_IMG_PKG" | cut -d';' -f2)-$(echo "$SYS_IMG_PKG" | cut -d';' -f3- | base64 | tr -d '\n' | sed 's/=*$//')
echo "AVD_NAME: $AVD_NAME"
echo "System image package: $SYS_IMG_PKG"
sdkmanager "$SYS_IMG_PKG"

# Check if AVD exists
if ! avdmanager list avd | grep -q "Name: $AVD_NAME"; then
    echo "Creating AVD: $AVD_NAME"
    # Create a new AVD
    echo "no" | avdmanager create avd --force --name "$AVD_NAME" --package "$SYS_IMG_PKG" --device "pixel"
else
    echo "AVD '$AVD_NAME' already exists."
fi

./bin/start-avd.sh $AVD_NAME