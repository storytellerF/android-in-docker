#!/bin/bash

sudo chown -R $(whoami):$(whoami) $HOME/log/supervisor

# 获取/dev/kvm 所属的组
KVM_GROUP=$(stat -c %G /dev/kvm)
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