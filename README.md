# Android in Docker

在 Docker 容器里运行 Android Emulator、noVNC、ADB、Appium 和 Docker-in-Docker 的开发/测试环境。适合做 Android 自动化测试、远程调试，以及把 Android 开发工具链封装进可复现的容器。

## 功能概览

- Android Emulator + Android SDK 自动安装与 AVD 自动创建。
- noVNC Web 桌面、原生 VNC、ADB、Appium Server。
- Docker-in-Docker，便于在容器内继续构建或运行 Docker 任务。
- 标准镜像和开发镜像两种模式；开发镜像额外包含 SSH、浏览器、Android Studio 等工具。
- 支持 Debian、Ubuntu、Fedora、Arch、Alpine 基础系统。
- 支持 OpenJDK 和 Eclipse Temurin；支持中国镜像源变体。

## 快速开始

初始化 submodule：

```sh
git submodule update --init --recursive
```

创建外部卷。标准运行至少需要 `sdk_data`；开发模式还需要 `gradle_data`：

```sh
docker volume create sdk_data
docker volume create gradle_data
```

首次生成或更新 `.env`：

```sh
./scripts/build-image.sh -c
```

启动标准环境：

```sh
./scripts/build-image.sh -S
```

启动开发环境：

```sh
./scripts/build-image.sh -D -S
```

端口由 Docker 自动分配。启动后脚本会打印访问地址，也可以随时查看：

```sh
docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml -f docker/compose/docker-compose.privileged.yml ps
```

常用入口：

- noVNC: `http://localhost:<PORT>/vnc.html`
- VNC: `localhost:<PORT>`
- ADB: `adb connect localhost:<PORT>`
- Appium Inspector: `http://localhost:<PORT>/inspector`
- SSH: `ssh -p <PORT> debian@localhost`，仅开发环境可用

## 构建镜像

本地构建标准镜像：

```sh
./scripts/build-image.sh -b
```

构建并启动：

```sh
./scripts/build-image.sh -b -S
```

构建中国镜像源变体：

```sh
./scripts/build-image.sh -b --cn-mirror
```

使用 Temurin：

```sh
./scripts/build-image.sh -b --jdk-provider temurin
```

构建指定基础系统：

```sh
./scripts/build-image.sh -b -s ubuntu -v noble
./scripts/build-image.sh -b -s fedora -v 44
```

构建开发镜像：

```sh
./scripts/build-image.sh -b -D
```

开发镜像会从 `download/android-studio-*.tar.gz` 复制 Android Studio。如果构建开发镜像，请先把 Android Studio Linux tarball 放到 `download/` 目录。

发布多架构镜像：

```sh
./scripts/build-image.sh -P -m --latest
```

停止服务：

```sh
./scripts/build-image.sh -T
./scripts/build-image.sh -D -T
```

启用 Bash 补全：

```sh
source scripts/completion.bash
```

## build-image.sh 选项

| 选项 | 说明 |
| --- | --- |
| `--jdk-provider <openjdk|temurin>` | JDK 提供方，默认 `openjdk` |
| `-j, --jdk-version <version>` | JDK 主版本，默认 `21` |
| `-p, --password <password>` | VNC 密码 |
| `-i, --system-image <package>` | Android system image package |
| `-d, --desktop <xfce|lxqt|mate>` | 桌面环境，默认 `xfce` |
| `-z, --timezone <timezone>` | 时区；默认从宿主机检测 |
| `--cn-mirror` | 强制使用中国镜像源和 `cn` tag |
| `--no-cn-mirror` | 禁用中国镜像源变体 |
| `-s, --system <system>` | 基础系统：`debian`、`ubuntu`、`fedora`、`arch`、`alpine` |
| `-v, --version <version>` | 基础系统版本 |
| `-c, --create-env` | 创建或更新 `.env` |
| `-b, --build` | 执行 Docker build |
| `-D, --dev` | 构建/启动开发环境 |
| `-S, --start` | 启动 Docker Compose |
| `-T, --stop` | 停止 Docker Compose |
| `-P, --publish` | 使用 buildx 构建并推送 |
| `-m, --multi-arch` | 多架构模式 |
| `--latest` | 额外打 `latest` tag |
| `--no-snapshot` | 不打 `snapshot` tag |

## 配置

`.env` 是主要配置入口，常用字段如下：

```dotenv
DOCKER_USERNAME="storytellerf"
VNC_PASSWD="password"
IMAGE_TAG_TIME="20260517020454"
OPENJDK_VERSION="21"
```

`IMAGE_TAG_TIME` 会参与镜像 tag。只要该值有效，多次构建会复用相同 tag，避免因为当前时间变化而产生不同镜像名。

## 镜像 Tag

完整 tag 前缀格式：

```text
<system>-<version>-<desktop>-<jdk-provider><jdk-version>[-cn][-dev]-<label>
```

示例：

- `debian-trixie-xfce-openjdk21-snapshot`
- `debian-trixie-xfce-openjdk21-cn-latest`
- `debian-trixie-xfce-openjdk21-dev-20260517020454`
- `debian-trixie-xfce-temurin21-snapshot`

脚本还会为默认字段生成短 tag。默认字段包括 `debian`、`trixie`、`xfce`、`openjdk21`。

示例：

- `debian-trixie-xfce-openjdk21-snapshot` 额外生成 `snapshot`
- `debian-trixie-xfce-openjdk21-cn-snapshot` 额外生成 `cn-snapshot`
- `debian-trixie-xfce-openjdk21-dev-snapshot` 额外生成 `dev-snapshot`
- `debian-trixie-xfce-temurin21-snapshot` 额外生成 `temurin21-snapshot`

## Compose 文件

基础 compose：

- `docker/compose/docker-compose.yml`: 标准服务、端口、日志和 SDK/AVD 卷。
- `docker/compose/docker-compose.kvm.yml`: 挂载 `/dev/kvm`，适合原生 Linux。
- `docker/compose/docker-compose.privileged.yml`: privileged 模式，适合需要更宽权限的环境。
- `docker/compose/docker-compose.dev.yml`: 开发环境覆盖项，增加 SSH 和开发工具缓存卷。

`build-image.sh -S` 会自动组合这些文件。标准环境会加载基础、KVM 和 privileged 配置；开发环境会额外加载 dev 配置。

## 目录结构

- `scripts/build-image.sh`: 统一构建、发布、启动、停止入口。
- `scripts/open-vnc.sh`: 自动检测 VNC 端口并打开本机 VNC 客户端。
- `scripts/setup-devcontainer.sh`: 在其他项目中生成 `.devcontainer` 配置。
- `scripts/add-ssh-key.sh`: 给 devcontainer 的 `authorized_keys` 追加 SSH 公钥。
- `base-scripts/`: 容器内启动 Android、Appium、SSH 等服务的脚本。
- `docker/dockerfiles/android/`: 标准运行镜像 Dockerfile。
- `docker/dockerfiles/dev/`: 开发镜像 Dockerfile。
- `docker/dockerfiles/*/fragments/`: JDK、Node、Docker-in-Docker 等注入片段。
- `docker/config/supervisor/`: supervisor 服务配置。
- `docker/config/appium/appium-capability.json`: Appium capability 示例。
- `external/android-profile/`: Android SDK、AVD 创建与启动脚本 submodule。
- `external/docker/`: Docker 官方入口脚本 submodule。
- `tests/verify-fake-docker.sh`: 使用假 Docker 验证构建脚本流程。

## Dev Container

可以在任意项目根目录运行本仓库脚本，生成一套可用的 Dev Container 配置：

```sh
/path/to/android-in-docker/scripts/setup-devcontainer.sh
```

生成后按需修改 `.devcontainer/dev.Dockerfile` 的基础镜像 tag，例如切换到 `*-cn-dev-*`。如果需要 SSH 免密登录：

```sh
cd .devcontainer
/path/to/android-in-docker/scripts/add-ssh-key.sh
```

架构相关的 Android system image 已在生成的 `custom-entrypoint.sh` 中处理：`x86_64` 使用 `system-images;android-36;google_apis;x86_64`，其他架构使用 `system-images;android-36;google_apis;arm64`。

## 日志与调试

日志挂载到宿主机 `./logs`：

```sh
tail -f ./logs/android.stdout.log
tail -f ./logs/android.stderr.log
```

进入容器：

```sh
docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml -f docker/compose/docker-compose.privileged.yml exec android bash
```

查看 supervisor 服务：

```sh
docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml -f docker/compose/docker-compose.privileged.yml exec android supervisorctl status
```

打开原生 VNC 客户端：

```sh
./scripts/open-vnc.sh
```

验证构建脚本，不会真实构建或启动 Docker：

```sh
./tests/verify-fake-docker.sh
```

## 注意事项

- 首次启动会下载 Android SDK、system image 和默认组件，耗时取决于网络。
- Linux 宿主机建议启用 KVM，并确认当前用户有 `/dev/kvm` 访问权限。
- WSL/Windows 环境通常需要 privileged 配置，模拟器性能和可用性取决于宿主虚拟化能力。
- Alpine 镜像主要用于构建验证；Android Studio/Emulator 官方 Linux 运行要求 glibc，Alpine 运行属于实验性场景。
- 如果使用 `--cn-mirror` 或位于中国时区，脚本会优先使用中国镜像源变体。
