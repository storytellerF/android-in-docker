#!/bin/bash

# 脚本：添加SSH公钥到authorized_keys文件
# 如果提供了公钥参数，则使用该参数；否则在.ssh目录中搜索公钥文件

set -e

# 设置输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 目标文件路径
AUTHORIZED_KEYS_FILE="./data/authorized_keys"

# 创建data目录（如果不存在）
mkdir -p "./data"

echo -e "${GREEN}开始添加SSH公钥到 ${AUTHORIZED_KEYS_FILE}${NC}"

# 检查是否提供了公钥参数
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}未提供公钥参数，正在搜索本地.ssh目录中的公钥...${NC}"
    
    # 尝试查找本地.ssh目录中的公钥
    SSH_DIR="$HOME/.ssh"
    if [ -d "$SSH_DIR" ]; then
        # 查找常见的公钥文件
        PUB_KEY_PATH=""
        
        # 按优先级顺序查找公钥文件
        for pub_key in id_rsa.pub id_ecdsa.pub id_ed25519.pub id_dsa.pub; do
            if [ -f "$SSH_DIR/$pub_key" ]; then
                PUB_KEY_PATH="$SSH_DIR/$pub_key"
                echo -e "${GREEN}找到公钥文件: $PUB_KEY_PATH${NC}"
                break
            fi
        done
        
        if [ -z "$PUB_KEY_PATH" ]; then
            echo -e "${RED}错误: 在 $SSH_DIR 目录中找不到任何公钥文件 (id_rsa.pub, id_ecdsa.pub, id_ed25519.pub, id_dsa.pub)${NC}"
            echo -e "${YELLOW}请确保你已经生成了SSH密钥对，或者手动提供公钥内容作为参数${NC}"
            exit 1
        fi
        
        # 读取公钥内容
        PUB_KEY_CONTENT=$(cat "$PUB_KEY_PATH")
    else
        echo -e "${RED}错误: $SSH_DIR 目录不存在${NC}"
        echo -e "${YELLOW}请确保你有SSH目录，或者手动提供公钥内容作为参数${NC}"
        exit 1
    fi
else
    # 使用提供的参数作为公钥内容
    PUB_KEY_CONTENT="$1"
    echo -e "${GREEN}使用提供的公钥内容${NC}"
fi

# 验证公钥格式
if [[ ! "$PUB_KEY_CONTENT" =~ ^ssh-(rsa|dss|ed25519) ]]; then
    echo -e "${RED}警告: 公钥格式可能不正确，应该以 ssh-rsa, ssh-dss 或 ssh-ed25519 开头${NC}"
    read -p "是否继续? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}操作已取消${NC}"
        exit 1
    fi
fi

# 检查目标文件是否存在，如果不存在则创建
if [ ! -f "$AUTHORIZED_KEYS_FILE" ]; then
    touch "$AUTHORIZED_KEYS_FILE"
    chmod 600 "$AUTHORIZED_KEYS_FILE"
    echo -e "${GREEN}已创建 $AUTHORIZED_KEYS_FILE 文件${NC}"
fi

# 检查公钥是否已经存在于authorized_keys中
if echo "$PUB_KEY_CONTENT" | grep -Fxq "$(echo "$PUB_KEY_CONTENT" | tr -d '\r\n')" "$AUTHORIZED_KEYS_FILE"; then
    echo -e "${YELLOW}公钥已存在于 $AUTHORIZED_KEYS_FILE 中${NC}"
else
    # 添加公钥到authorized_keys文件
    echo "$PUB_KEY_CONTENT" >> "$AUTHORIZED_KEYS_FILE"
    chmod 600 "$AUTHORIZED_KEYS_FILE"
    echo -e "${GREEN}公钥已成功添加到 $AUTHORIZED_KEYS_FILE${NC}"
fi

echo -e "${GREEN}操作完成！${NC}"

# 显示authorized_keys文件的当前内容
echo -e "\n${YELLOW}$AUTHORIZED_KEYS_FILE 当前内容:${NC}"
cat "$AUTHORIZED_KEYS_FILE"