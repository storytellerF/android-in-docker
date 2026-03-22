# Android in Docker

提供一个在 Docker 容器中运行 Android Emulator、VNC（noVNC）和 Appium 的环境，方便进行自动化测试与调试。

## 快速开始

1. 如果还没有外部 SDK 卷（在 `docker-compose.yml` 中声明为 `sdk_data`），先创建它：

    ```sh
    docker volume create sdk_data
    ```

2. 使用脚本构建镜像：

    ```sh
    ./build-image.sh [OPTIONS]
    ```

    **常用选项**：
    - `-b, --build`: 本地构建镜像。
    - `-D, --dev`: 构建开发版镜像（基于 `dev.Dockerfile`，包含 SSH, Chrome 等）。
    - `-j, --jdk-version`: 指定 OpenJDK 版本（默认 21）。
    - `-P, --publish`: 构建并发布多架构镜像到 Docker Hub。
    - `-S, --start`: 构建后自动启动 Docker Compose。

    **示例**：
    ```sh
    # 1. 首次配置环境（交互式）
    ./build-image.sh -c

    # 2. 本地构建标准版镜像
    ./build-image.sh -b

    # 3. 构建并启动开发版（包含 SSH 和 Chrome）
    ./build-image.sh -D -S
    ```

    **启用 Bash 补全**：
    
    ```bash
    source completion.bash
    ```
    
    之后可以使用 TAB 键补全参数。

3. 通过脚本一键启动（推荐）

    ```sh
    ./build-image.sh -S
    ```

    脚本会根据环境自动选择配置：
    - **WSL/Windows**: 使用 `docker-compose.privileged.yml`。
    - **Native Linux**: 使用 `docker-compose.kvm.yml`。
    - **开发模式 (-D)**: 额外加载 `docker-compose.dev.yml`。

4. 连接与验证

    - **noVNC（Web VNC）**: <http://localhost:6080/vnc.html>
    - **直接 VNC**: `localhost:5901`
    - **ADB**: `adb connect localhost:5555`
    - **Appium**: <http://localhost:4723/inspector>
    - **SSH (仅开发版)**: `ssh -p 2222 debian@localhost` (默认密码: `password` 可在 `.env` 修改)

## 主要文件与脚本

- **构建相关**
  - `Dockerfile`: 标准镜像定义。
  - `dev.Dockerfile`: 开发版镜像定义（包含 SSH, Chrome, Android Studio 等）。
  - `build-image.sh`: 统一构建与启动入口。

- **核心脚本 (位于 `base-scripts/`)**
  - `start-android.sh`: 启动 Android Emulator（自动调用 `install-sdk.sh`）。
  - `start-vnc.sh`: 启动 VNC 服务。
  - `start-appium.sh`: 启动 Appium Server.
  - `entrypoint.sh`: 容器入口脚本。

- **配置管理**
  - `supervisord.conf`: 基础进程管理。
  - `ssh.supervisord.conf`: SSH 服务进程配置。
  - `.env`: 环境变量配置（参考 `env-example`）。

## 镜像 Tag 策略

生成的 Tag 格式为：`openjdk{JDK_VERSION}.{BASE_VERSION}.{DATE}[-dev]`

- **JDK_VERSION**: OpenJDK 版本（默认 21）。
- **BASE_VERSION**: 基础操作系统版本（如 `trixie`）。
- **DATE**: 构建时间戳 (YYYYMMDDHHMMSS)。
- **-dev**: 仅开发版镜像带有此后缀。

例如：`openjdk21.trixie.20240314120000-dev`

生成的 Tag 会自动同步到 `.env` 的 `IMAGE_TAG` 中。

## 卷与持久化

docker-compose 已配置以下卷（见 [`docker-compose.yml`](docker-compose.yml)）：

- `avd_data`: 保存虚拟设备数据（`/home/debian/.android/avd`）。
- `sdk_data`: 持久化 Android SDK（外部卷，`/home/debian/Android/Sdk`）。
- **开发版额外卷**:
    - `chrome_cache/config`: Chrome 浏览器的缓存与配置。
    - `google_cache/config/local`: Google 相关服务的持久化。

## 日志与调试

日志映射到宿主机 `./logs` 目录：
- 容器内路径：`/home/debian/log/supervisor/*.log`
- 宿主机查看：`tail -f ./logs/android.stdout.log`

## 常见操作

- 重建镜像并重启：

```sh
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

- **进入容器调试**:
  ```sh
  docker compose exec android bash
  ```

- 通过 ADB 连接（宿主）：

```sh
adb connect localhost:5555
adb devices
```

- **查看服务状态**:
  ```sh
  docker compose exec android supervisorctl status
  ```

## 注意事项

- **首次启动**: 会自动下载 Android SDK 及其组件，耗时较长，请确保网络畅通。
- **权限**: 在 Linux 宿主机上运行通常需要 `SYS_ADMIN` 能力和 `/dev/kvm` 访问权限。
- **自定义配置**: 建议通过修改 `.env` 文件或 `build-image.sh -c` 来快速调整参数。

# 在Dev Container 中使用

.devcontainer/.env

```
COMPOSE_PROJECT_NAME=a-dev-container
CONTAINER_USERNAME=debian
CONTAINER_HOME=/home/debian
VNC_PASSWD=password
```

.devcontainer/devcontainer.json

```json
// For format details, see https://aka.ms/devcontainer.json. For config options, see the
// README at: https://github.com/devcontainers/templates/tree/main/src/docker-existing-dockerfile
{
	"name": "You Dev Container Name",
	"dockerComposeFile": [
		"./docker-compose.yml"
	],
	"service": "main",
	"workspaceFolder": "/workspace/your-project-name",
	"shutdownAction": "stopCompose",
	// Features to add to the dev container. More info: https://containers.dev/features.
	// "features": {},
	// Use 'forwardPorts' to make a list of ports inside the container available locally.
	// "forwardPorts": [],
	// Uncomment the next line to run commands after the container is created.
	// "postCreateCommand": "cat /etc/os-release",
	// Configure tool-specific properties.
	// "customizations": {},
	// Uncomment to connect as an existing user other than the container default. More info: https://aka.ms/dev-containers-non-root.
	"remoteUser": "debian"
}
```

.devcontainer/docker-compose.yml

```yaml
services:
  main:
    build:
      context: ..
      dockerfile: ./dev.Dockerfile
      args:
        - USER_NAME=${CONTAINER_USERNAME}
    ports:
      - "6081:6080" # noVNC web interface
      - "5902:5901" # VNC direct connection
      - "5556:5555" # ADB
      - "4724:4723" # Appium
      - "4422:22" # ssh
    environment:
      - VNC_PASSWD=${VNC_PASSWD}
      - TESTCONTAINERS_HOST_OVERRIDE=host.docker.internal # 如果需要Test Container 的话
      - VNC_GEOMETRY=1920x1080
      - VNC_DEPTH=24
    volumes:
      - ..:/workspace/your-project-name:cached
      - ./data/authorized_keys:${CONTAINER_HOME}/.ssh/authorized_keys
      - ~/.gradle/gradle.properties:${CONTAINER_HOME}/.gradle/gradle.properties # 如果需要GithHub Packages
      - /var/run/docker.sock:/var/run/docker.sock # 宿主机 Docker 套接字
      - avd_data:${CONTAINER_HOME}/.android/avd
      - sdk_data:${CONTAINER_HOME}/Android/Sdk
      - bash_history:${CONTAINER_HOME}/.android-in-docker/.bash_history
      - gradle_data:${CONTAINER_HOME}/.gradle
      - konan_data:${CONTAINER_HOME}/.konan
      - m2_data:${CONTAINER_HOME}/.m2
      - chrome_cache:${CONTAINER_HOME}/.cache/google-chrome
      - chrome_config:${CONTAINER_HOME}/.config/google-chrome
      - google_cache:${CONTAINER_HOME}/.cache/Google
      - google_config:${CONTAINER_HOME}/.config/Google
      - google_local:${CONTAINER_HOME}/.local/share/Google
      - antigravity_config:${CONTAINER_HOME}/.config/Antigravity
      - gemini_data:${CONTAINER_HOME}/.gemini
      - antigravity_data:${CONTAINER_HOME:-/home/debian}/.antigravity
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
```

需要根据架构更换镜像，否则不会启动模拟器

custom-entrypoint.sh
```sh
#!/bin/bash

set -e
# check arch select SYS_IMG_PKG
if [ "$(uname -m)" = "x86_64" ]; then
    export SYS_IMG_PKG="system-images;android-36;google_apis;x86_64"
else
    export SYS_IMG_PKG="system-images;android-36;google_apis;arm64"
fi

./bin/entrypoint.sh
```

dev.Dockerfile

```Dockerfile
FROM storytellerf/android-in-docker:latest-dev

ARG USER_NAME

USER root

# 如果需要中文输入法
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y fcitx fcitx-googlepinyin

# 如果需要在容器中访问docker 的话
RUN groupadd -g 1001 docker \
    && usermod -aG docker $USER_NAME

USER $USER_NAME
WORKDIR /home/$USER_NAME

COPY --chown=$USER_NAME:$USER_NAME ./custom-entrypoint.sh ./bin/custom-entrypoint.sh
RUN chmod +x ./bin/custom-entrypoint.sh

ENTRYPOINT ["sh", "-c", "$HOME/bin/custom-entrypoint.sh"]

```

添加ssh 公钥

```shell
cd .devcontainer && /path/to/android-in-docker/add-ssh-key.sh
```