#!/bin/bash

# 需要在root下执行

set -e

SYS_IMG_PKG=$1
BUILD_TOOLS_PKG=$2
PLATFORM_PKG=$3

if [ -z "$SYS_IMG_PKG" ] || [ -z "$BUILD_TOOLS_PKG" ] || [ -z "$PLATFORM_PKG" ]; then
    echo "Usage: $0 <system-image-package> <build-tools-package> <platform-package>"
    echo "Example: $0 'system-images;android-36;google_apis;x86_64' 'build-tools;36.0.0' 'platforms;android-36'"
    exit 1
fi

# Ensure the base directory exists and we have permissions
mkdir -p ${ANDROID_HOME}
chown -R root:root ${ANDROID_HOME}
chmod -R 755 ${ANDROID_HOME}

if ! sdkmanager --list_installed | grep -q "${SYS_IMG_PKG}"; then
    echo "Installing system image (${SYS_IMG_PKG})..."
    sdkmanager "${SYS_IMG_PKG}"
else
    echo "System image (${SYS_IMG_PKG}) already installed."
fi

if ! sdkmanager --list_installed | grep -q "${BUILD_TOOLS_PKG}"; then
    echo "Installing build tools (${BUILD_TOOLS_PKG})..."
    # 自动接受许可并安装
   sdkmanager "${BUILD_TOOLS_PKG}"
else
    echo "Build tools (${BUILD_TOOLS_PKG}) already installed."
fi

if ! sdkmanager --list_installed | grep -q "${PLATFORM_PKG}"; then
    echo "Installing platform (${PLATFORM_PKG})..."
    sdkmanager "${PLATFORM_PKG}"
else
    echo "Platform (${PLATFORM_PKG}) already installed."
fi