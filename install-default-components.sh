#!/bin/bash
set -e

SYS_IMG_PKG=$1
BUILD_TOOLS_PKG=$2
PLATFORM_PKG=$3

if [ -z "$SYS_IMG_PKG" ] || [ -z "$BUILD_TOOLS_PKG" ] || [ -z "$PLATFORM_PKG" ]; then
    echo "Usage: $0 <system-image-package> <build-tools-package> <platform-package>"
    echo "Example: $0 'system-images;android-36;google_apis;x86_64' 'build-tools;36.0.0' 'platforms;android-36'"
    exit 1
fi

# Set Android SDK root
export ANDROID_SDK_ROOT=/opt/android/sdk
export PATH=$PATH:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator

# Ensure the base directory exists and we have permissions
mkdir -p ${ANDROID_SDK_ROOT}
chown -R root:root ${ANDROID_SDK_ROOT}
chmod -R 755 ${ANDROID_SDK_ROOT}

if ! sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --list_installed | grep -q "${SYS_IMG_PKG}"; then
    echo "Installing system image (${SYS_IMG_PKG})..."
    sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "${SYS_IMG_PKG}"
else
    echo "System image (${SYS_IMG_PKG}) already installed."
fi

if ! sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --list_installed | grep -q "${BUILD_TOOLS_PKG}"; then
    echo "Installing build tools (${BUILD_TOOLS_PKG})..."
    # 自动接受许可并安装
   sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "${BUILD_TOOLS_PKG}"
else
    echo "Build tools (${BUILD_TOOLS_PKG}) already installed."
fi

if ! sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --list_installed | grep -q "${PLATFORM_PKG}"; then
    echo "Installing platform (${PLATFORM_PKG})..."
    sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "${PLATFORM_PKG}"
else
    echo "Platform (${PLATFORM_PKG}) already installed."
fi