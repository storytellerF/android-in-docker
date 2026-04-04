#!/bin/bash
set -e

# Usage: ./install-appium.sh <timezone>
TIMEZONE=${1:?"Timezone argument is required"}

echo "Setting up Appium (Timezone: $TIMEZONE)..."

# Check if we should use Chinese mirrors
if [[ "$TIMEZONE" == "Asia/Shanghai" || "$TIMEZONE" == "Asia/Chongqing" || "$TIMEZONE" == "PRC" ]]; then
    echo "Timezone detected as China ($TIMEZONE). Using Chinese mirrors..."
    sudo npm install -g nrm && sudo nrm use taobao && nrm use taobao
else
    echo "Timezone is $TIMEZONE. Using default NPM registry."
fi

# Setup Appium，全局安装会安装到/usr/local/lib/node_modules，需要sudo权限
echo "Installing Appium..."
sudo npm install -g appium

# Setup appium driver and plugin，安装到~/.appium，不需要sudo权限
# npm_config_registry 从 ~/.npmrc 中读取，无需硬编码
echo "Installing Appium drivers and plugins..."
appium driver install uiautomator2
appium plugin install storage
appium plugin install inspector

echo "Appium setup completed successfully."
