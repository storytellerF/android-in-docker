#!/bin/bash
set -e

# Set Android SDK root
export ANDROID_SDK_ROOT=/opt/android/sdk
export PATH=$PATH:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${ANDROID_SDK_ROOT}/emulator

# Ensure the base directory exists and we have permissions
mkdir -p ${ANDROID_SDK_ROOT}
chown -R root:root ${ANDROID_SDK_ROOT}
chmod -R 755 ${ANDROID_SDK_ROOT}

# Check if command line tools are already installed
if [ -d "${ANDROID_SDK_ROOT}/cmdline-tools/latest" ]; then
    echo "Android SDK command-line tools already found. Skipping download."
else
    echo "Android SDK command-line tools not found. Downloading..."

    wget -O commandline-tools.zip "https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
    unzip commandline-tools.zip -d ${ANDROID_SDK_ROOT}/cmdline-tools
    mv ${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools ${ANDROID_SDK_ROOT}/cmdline-tools/latest
    rm commandline-tools.zip
    echo "Android SDK command-line tools installed."
fi

# Accept all licenses silently before attempting to download components
yes | sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --licenses > /dev/null

# 使用sdkmanager 获取当前最新的command line tools版本号
LATEST_CLI_VERSION=$(sdkmanager --sdk_root=${ANDROID_SDK_ROOT} --list | grep "command line tools" | awk '{print $NF}')
echo "Latest command line tools version available: $LATEST_CLI_VERSION"
# 通过source.properties文件获取command line tools的版本号，如果不是最新的下载更新
CLI_VERSION=$(grep "Pkg.Revision" ${ANDROID_SDK_ROOT}/cmdline-tools/latest/source.properties | awk -F '=' '{print $2}')
echo "Current command line tools version: $CLI_VERSION"
# 如果版本号不是空，并且不同才更新
if [ -n "$CLI_VERSION" ] && [ -n "$LATEST_CLI_VERSION" ] && [ "$CLI_VERSION" != "$LATEST_CLI_VERSION" ]; then
    # 使用sdkmanager更新command line tools
    echo "Updating command line tools to the latest version..."
    sdkmanager --sdk_root=${ANDROID_SDK_ROOT} "cmdline-tools;latest"
    echo "Android SDK command-line tools updated to version $LATEST_CLI_VERSION."
else
    echo "Android SDK command-line tools are up to date."
fi

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
