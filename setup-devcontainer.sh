#!/bin/bash

# setup-devcontainer.sh
# 此脚本用于在当前项目中初始化基于 storytellerf/android-in-docker 的 devcontainer 配置。
# 请在目标项目的根目录下执行此脚本。
# 示例： /path/to/android-in-docker/setup-devcontainer.sh

set -e

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

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
	"remoteUser": "debian",
	"customizations": {
		"vscode": {
			"extensions": [
				// 在此处添加你需要的 VS Code 插件
			]
		}
	}
}
EOF

# 3. 生成 docker-compose.yml
echo -e "${YELLOW}生成 ${DEVCONTAINER_DIR}/docker-compose.yml${NC}"
cat > "${DEVCONTAINER_DIR}/docker-compose.yml" <<EOF
services:
  main:
    build:
      context: ..
      dockerfile: .devcontainer/dev.Dockerfile
      args:
        - USER_NAME=\${CONTAINER_USERNAME}
    ports:
      - "6081:6080" # noVNC web interface
      - "5902:5901" # VNC direct connection
      - "5556:5555" # ADB
      - "4724:4723" # Appium
      - "4422:22" # ssh
    environment:
      - VNC_PASSWD=\${VNC_PASSWD}
      - TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal # 如果需要Test Container的话
      - VNC_GEOMETRY=1920x1080
      - VNC_DEPTH=24
    volumes:
      - ..:/workspace/${PROJECT_NAME}:cached
      - \${ANDROID_IN_DOCKER_PATH}/data/authorized_keys:\${CONTAINER_HOME}/.ssh/authorized_keys
      - ~/.gradle/gradle.properties:\${CONTAINER_HOME}/.gradle/gradle.properties # 如果需要GitHub Packages
      - /var/run/docker.sock:/var/run/docker.sock # 宿主机 Docker 套接字
      - avd_data:\${CONTAINER_HOME}/.android/avd
      - sdk_data:\${CONTAINER_HOME}/Android/Sdk
      - bash_history:\${CONTAINER_HOME}/.android-in-docker/.bash_history
      - gradle_data:\${CONTAINER_HOME}/.gradle
      - konan_data:\${CONTAINER_HOME}/.konan
      - m2_data:\${CONTAINER_HOME}/.m2
      - chrome_cache:\${CONTAINER_HOME}/.cache/google-chrome
      - chrome_config:\${CONTAINER_HOME}/.config/google-chrome
      - google_cache:\${CONTAINER_HOME}/.cache/Google
      - google_config:\${CONTAINER_HOME}/.config/Google
      - google_local:\${CONTAINER_HOME}/.local/share/Google
      - antigravity_config:\${CONTAINER_HOME}/.config/Antigravity
      - gemini_data:\${CONTAINER_HOME}/.gemini
      - antigravity_data:\${CONTAINER_HOME}/.antigravity
    shm_size: '2gb' # Allocate more shared memory
    privileged: true # Enable KVM acceleration

volumes:
  avd_data:
  sdk_data:
    name: sdk_data
    external: true
  bash_history:
  gradle_data:
  konan_data:
  m2_data:
  chrome_cache:
  chrome_config:
  google_cache:
  google_config:
  google_local:
  antigravity_config:
  gemini_data:
  antigravity_data:
EOF

# 替换 docker-compose 中的 ANDROID_IN_DOCKER_PATH
sed -i "s|\${ANDROID_IN_DOCKER_PATH}|${SCRIPT_DIR}|g" "${DEVCONTAINER_DIR}/docker-compose.yml"

# 4. 生成 custom-entrypoint.sh
echo -e "${YELLOW}生成 ${DEVCONTAINER_DIR}/custom-entrypoint.sh${NC}"
cat > "${DEVCONTAINER_DIR}/custom-entrypoint.sh" <<'EOF'
#!/bin/bash

set -e
# check arch select SYS_IMG_PKG
if [ "$(uname -m)" = "x86_64" ]; then
    export SYS_IMG_PKG="system-images;android-36;google_apis;x86_64"
else
    export SYS_IMG_PKG="system-images;android-36;google_apis;arm64"
fi

./bin/entrypoint.sh
EOF

# 5. 生成 dev.Dockerfile
echo -e "${YELLOW}生成 ${DEVCONTAINER_DIR}/dev.Dockerfile${NC}"
cat > "${DEVCONTAINER_DIR}/dev.Dockerfile" <<EOF
FROM storytellerf/android-in-docker:latest-dev

ARG USER_NAME

USER root

# 如果需要中文输入法
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y fcitx fcitx-googlepinyin

# 如果需要在容器中访问docker
RUN groupadd -g 1001 docker \\
    && usermod -aG docker \$USER_NAME

USER \$USER_NAME
WORKDIR /home/\$USER_NAME

COPY --chown=\$USER_NAME:\$USER_NAME ./custom-entrypoint.sh ./bin/custom-entrypoint.sh
RUN chmod +x ./bin/custom-entrypoint.sh

ENTRYPOINT ["sh", "-c", "\$HOME/bin/custom-entrypoint.sh"]
EOF

echo -e "${GREEN}完成！${NC}"
echo -e "接下来你可以："
echo -e "1. 检查生成的 .devcontainer 目录下的文件是否符合需求"
echo -e "2. 如果需要配置 SSH 免密登录，请运行: ${YELLOW}cd .devcontainer && ${SCRIPT_DIR}/add-ssh-key.sh${NC}"
echo -e "3. 使用 VS Code 打开当前目录，并在提示时选择 'Reopen in Container'"
