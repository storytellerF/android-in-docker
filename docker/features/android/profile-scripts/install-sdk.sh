#!/bin/bash
set -e

version_lt() {
    [ "$1" = "$2" ] && return 1
    local IFS=.
    local i ver1=($1) ver2=($2)
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do ver1[i]=0; done
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]} ]]; then ver2[i]=0; fi
        if ((10#${ver1[i]} < 10#${ver2[i]})); then return 0; fi
        if ((10#${ver1[i]} > 10#${ver2[i]})); then return 1; fi
    done
    return 1
}

mkdir -p ${ANDROID_HOME}
sudo chown -R $(whoami):$(whoami) ${ANDROID_HOME}

download_and_install_cmdline_tools() {
    echo "Android SDK command-line tools not found or outdated. Downloading..."

    local download_url="https://dl.google.com/android/repository/commandlinetools-linux-13114758_latest.zip"
    if ! wget -O commandline-tools.zip "$download_url"; then
        echo "Error: Failed to download command-line tools from $download_url"
        return 1
    fi

    mkdir -p ${ANDROID_HOME}/cmdline-tools
    if ! unzip -q commandline-tools.zip -d ${ANDROID_HOME}/cmdline-tools; then
        echo "Error: Failed to extract command-line tools"
        rm -f commandline-tools.zip
        return 1
    fi

    rm -rf ${ANDROID_HOME}/cmdline-tools/latest
    mv ${ANDROID_HOME}/cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest
    rm -f commandline-tools.zip
    echo "Android SDK command-line tools installed."
}

if [ ! -d "${ANDROID_HOME}/cmdline-tools/latest" ]; then
    echo "Android SDK command-line tools not found. Installing..."
    download_and_install_cmdline_tools || exit 1
else
    echo "Android SDK command-line tools found."

    CLI_VERSION=$(grep "Pkg.Revision" ${ANDROID_HOME}/cmdline-tools/latest/source.properties 2>/dev/null | awk -F '=' '{print $2}')
    echo "Current command line tools version: ${CLI_VERSION:-unknown}"
    if version_lt "$CLI_VERSION" "19.0"; then
        echo "Updating command line tools to the latest version..."
        download_and_install_cmdline_tools || exit 1
    fi
fi

yes | sdkmanager --licenses > /dev/null 2>&1

LATEST_CLI_VERSION=$(sdkmanager --list | grep "cmdline-tools;latest" | awk '{print $3}' | sort -u)
echo "Latest command line tools version available: $LATEST_CLI_VERSION"

if [ -n "$CLI_VERSION" ] && [ -n "$LATEST_CLI_VERSION" ] && [ "$CLI_VERSION" != "$LATEST_CLI_VERSION" ]; then
    echo "Updating command line tools to the latest version..."
    mv ${ANDROID_HOME}/cmdline-tools/latest ${ANDROID_HOME}/cmdline-tools/backup-${CLI_VERSION}
    ${ANDROID_HOME}/cmdline-tools/backup-${CLI_VERSION}/bin/sdkmanager "cmdline-tools;latest"
    echo "Android SDK command-line tools updated to version $LATEST_CLI_VERSION."
    echo "You may want to remove the backup of the old command line tools at ${ANDROID_HOME}/cmdline-tools/backup-${CLI_VERSION} if everything works fine."
else
    echo "Android SDK command-line tools are up to date."
fi

if [ ! -d "${ANDROID_HOME}/platform-tools" ]; then
    echo "Installing platform-tools..."
    sdkmanager "platform-tools"
else
    echo "platform-tools already installed."
fi

if [ ! -d "${ANDROID_HOME}/emulator" ]; then
    echo "Installing emulator..."
    sdkmanager "emulator"
else
    echo "emulator already installed."
fi

echo "Android SDK setup is complete."
