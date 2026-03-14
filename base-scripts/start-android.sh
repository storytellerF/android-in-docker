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
AVD_NAME=$(echo "$SYS_IMG_PKG" | cut -d';' -f2)-$(echo "$SYS_IMG_PKG" | cut -d';' -f3- | base64 | tr -d '\n' | sed 's/=*$//')
echo "AVD_NAME: $AVD_NAME"
echo "System image package: $SYS_IMG_PKG"
sdkmanager "$SYS_IMG_PKG"

sudo chown -R $(whoami):$(whoami) ~/.android

# Check if AVD exists
if ! avdmanager list avd | grep -q "Name: $AVD_NAME"; then
    echo "Creating AVD: $AVD_NAME"
    # Create a new AVD
    echo "no" | avdmanager create avd --force --name "$AVD_NAME" --package "$SYS_IMG_PKG" --device "pixel"
else
    echo "AVD '$AVD_NAME' already exists."
fi

# 获取/dev/kvm 所属的组 ID
KVM_GID=$(stat -c %g /dev/kvm)

# 尝试获取组名
KVM_GROUP=$(getent group "$KVM_GID" | cut -d: -f1)

# 如果组名为空，说明只有组ID没有组名，需要创建自定义组
if [ -z "$KVM_GROUP" ]; then
    echo "Group ID $KVM_GID has no name. Creating custom kvm group..."
    KVM_GROUP="customkvm"
    sudo groupadd -g "$KVM_GID" "$KVM_GROUP" 2>/dev/null || {
        # 如果指定GID的组已存在，使用默认GID创建
        echo "Failed to create group with GID $KVM_GID, creating with default GID..."
        sudo groupadd "$KVM_GROUP"
    }
fi

# 检查当前用户是否在这个组中
if [ "$(id -gn)" != "$KVM_GROUP" ]; then
    echo "Adding user $(whoami) to group $KVM_GROUP..."
    sudo usermod -aG "$KVM_GROUP" "$(whoami)"
    echo "Re-login to group $KVM_GROUP..."
    sg "$KVM_GROUP" -c "./bin/start-avd.sh $AVD_NAME"
    exit 0
fi

./bin/start-avd.sh $AVD_NAME