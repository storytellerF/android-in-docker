#!/bin/bash

sudo chown -R $(whoami):$(whoami) $HOME/log/supervisor

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
    newgrp "$KVM_GROUP" -c "./bin/start-supervisord.sh"
    exit 0
fi

# Start supervisor
./bin/start-supervisord.sh