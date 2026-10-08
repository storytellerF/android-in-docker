#!/bin/bash

# setup-devcontainer.sh
# 此脚本用于在当前项目中初始化基于 storytellerf/android-in-docker 的 devcontainer 配置。
# 请在目标项目的根目录下执行此脚本。
# 示例： /path/to/android-in-docker/scripts/setup-devcontainer.sh

set -euo pipefail

# 设置输出颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 获取当前工作目录的名称作为项目名称
PROJECT_NAME=$(basename "$PWD")
DEVCONTAINER_DIR=".devcontainer"

echo -e "${GREEN}开始在当前目录初始化 ${PROJECT_NAME} 的 devcontainer 配置...${NC}"

# 创建 .devcontainer 目录
mkdir -p "$DEVCONTAINER_DIR"
mkdir -p "$DEVCONTAINER_DIR/logs" "$DEVCONTAINER_DIR/data" "$DEVCONTAINER_DIR/tmp"

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 初始化 SSH authorized_keys 文件
touch "${DEVCONTAINER_DIR}/data/authorized_keys"
chmod 600 "${DEVCONTAINER_DIR}/data/authorized_keys"

# 0. 生成 .gitignore
echo -e "${YELLOW}生成 ${DEVCONTAINER_DIR}/.gitignore${NC}"
cat > "${DEVCONTAINER_DIR}/.gitignore" <<'EOF'
data
tmp
logs
.env
EOF

# 1. 生成 .env
echo -e "${YELLOW}生成 ${DEVCONTAINER_DIR}/.env${NC}"
cat > "${DEVCONTAINER_DIR}/.env" <<EOF
COMPOSE_PROJECT_NAME=${PROJECT_NAME}-dev-container
CONTAINER_USERNAME=debian
CONTAINER_HOME=/home/debian
VNC_PASSWD=password
EOF

# 2. 生成 devcontainer.json
echo -e "${YELLOW}生成 ${DEVCONTAINER_DIR}/devcontainer.json${NC}"
cat > "${DEVCONTAINER_DIR}/devcontainer.json" <<EOF
{
  "name": "${PROJECT_NAME} Dev Container",
  "dockerComposeFile": [
    "./docker-compose.yml"
  ],
  "service": "main",
  "workspaceFolder": "/workspace/${PROJECT_NAME}",
  "shutdownAction": "stopCompose",
  "remoteUser": "debian"
}
EOF

# 3. 生成 docker-compose.yml
echo -e "${YELLOW}生成 ${DEVCONTAINER_DIR}/docker-compose.yml${NC}"
cat > "${DEVCONTAINER_DIR}/docker-compose.yml" <<EOF
services:
  main:
    build:
      context: ..
      dockerfile: ./.devcontainer/dev.Dockerfile
      args:
        - USER_NAME=\${CONTAINER_USERNAME}
    ports:
      - "6080" # noVNC web interface
      - "5901" # VNC direct connection
      - "4723" # Appium
      - "5555" # Emulator ADB
      - "22" # ssh
    environment:
      - VNC_PASSWD=\${VNC_PASSWD}
      - VNC_GEOMETRY=1920x1080
      - VNC_DEPTH=24
    volumes:
      - ..:/workspace/${PROJECT_NAME}:cached
      - ./logs:\${CONTAINER_HOME:-/home/debian}/log/supervisor
      - ./data/authorized_keys:\${CONTAINER_HOME}/.ssh/authorized_keys
      - sdk_data:\${CONTAINER_HOME}/Android/Sdk
      - avd_data:\${CONTAINER_HOME}/.android/avd
      - bash_history:\${CONTAINER_HOME}/.desktop-in-docker/.bash_history
      - firefox_cache:\${CONTAINER_HOME}/.cache/google-chrome
      - firefox_config:\${CONTAINER_HOME}/.config/google-chrome
      - google_cache:\${CONTAINER_HOME}/.cache/Google
      - google_config:\${CONTAINER_HOME}/.config/Google
      - google_local:\${CONTAINER_HOME}/.local/share/Google
      - vscode_data:\${CONTAINER_HOME}/.vscode
      - code_config:\${CONTAINER_HOME}/.config/Code
    shm_size: '2gb' # Allocate more shared memory

volumes:
  sdk_data:
  avd_data:
  bash_history:
  firefox_cache:
  firefox_config:
  google_cache:
  google_config:
  google_local:
  vscode_data:
  code_config:
EOF

# 4. 生成 dev.Dockerfile
echo -e "${YELLOW}生成 ${DEVCONTAINER_DIR}/dev.Dockerfile${NC}"
cat > "${DEVCONTAINER_DIR}/dev.Dockerfile" <<EOF
FROM storytellerf/android-in-docker:debian-trixie-xfce-openjdk21-latest

ARG USER_NAME

USER \$USER_NAME
WORKDIR /home/\$USER_NAME

EOF

echo -e "${GREEN}完成！${NC}"
echo -e "接下来你可以："
echo -e "1. 检查生成的 .devcontainer 目录下的文件是否符合需求"
echo -e "2. 如果需要配置 SSH 免密登录，请运行: ${YELLOW}cd .devcontainer && ${SCRIPT_DIR}/add-ssh-key.sh${NC}"
echo -e "3. 如果需要中国环境，请将 ${YELLOW}${DEVCONTAINER_DIR}/dev.Dockerfile${NC} 中的镜像 tag 改为 *-cn-*"
echo -e "4. 使用 VS Code 打开当前目录，并在提示时选择 'Reopen in Container'"
