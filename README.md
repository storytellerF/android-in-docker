# Android in Docker

容器化桌面与 Java 开发环境，提供 Appium 以实现 Android 自动化。每个镜像都包含 noVNC、VNC、JDK、Node.js、Python、Appium、SSH 和 Git。Debian/Ubuntu 和 Fedora 镜像还安装 VS Code。只提供一套镜像配置，无需区分标准模式与开发模式。

Android SDK 安装、AVD 创建和模拟器启动由固定版本的 `android-profile` 子模块提供。不包含 Android Studio 安装和 Docker-in-Docker。

## 环境要求

- Docker Engine 和 Docker Compose v2。
- 构建宿主上具备支持子模块的 Git、Python 3.10+ 和 Bash。
- 多平台发布需要 Docker Buildx 和镜像仓库访问权限。
- 能访问互联网以下载构建依赖。

构建脚本启动容器时映射 `/dev/kvm`，不需要特权模式。

## 快速开始

在仓库根目录运行命令，初始化固定版本的桌面源码依赖：

```sh
git submodule update --init --recursive
```

交互创建或更新 `.env`：

```sh
python3 scripts/build-image.py -c
```

在 `.env` 中将 `DOCKER_USERNAME` 设置为镜像命名空间，构建和 Compose 启动都会使用它。命名空间为空时，构建并启动本地镜像。构建成功后，将完整 `IMAGE_REF` 保存到 `.env`，Compose 使用该精确引用。直接使用 Compose 时，必须设置 `IMAGE_REF`。

构建并启动环境：

```sh
mkdir -p data
touch data/authorized_keys
python3 scripts/build-image.py -b -S
```

连接前，将 SSH 公钥添加到 `data/authorized_keys`。密码认证已禁用。

Docker 自动分配宿主端口，脚本启动后打印连接地址。可用服务如下：

| 服务 | 容器端口 | 连接方式 |
| --- | --- | --- |
| noVNC | 6080 | `http://localhost:<port>/vnc.html` |
| VNC | 5901 | `localhost:<port>` |
| Appium / Inspector | 4723 | 手动启动后访问 `http://localhost:<port>/inspector` |
| 模拟器 ADB | 5555 | 可用性取决于模拟器 profile 和网络绑定 |
| SSH | 22 | `ssh -p <port> debian@localhost` |

Appium 已安装，但不会由 Supervisor 启动。需要时在容器内手动启动：

```sh
~/bin/start-appium.sh
# Or: appium --use-plugins=storage,inspector --allow-cors
```

SSH 用户名取决于基础系统：Debian 为 `debian`，Ubuntu 为 `ubuntu`，Fedora 为 `user`，Alpine 为 `alpine`。

不构建而直接启动已有镜像，或停止环境：

```sh
python3 scripts/build-image.py -S
python3 scripts/build-image.py -T
```

## 构建镜像

构建顺序为：

```text
desktop base layer → desktop image → Android development image
```

桌面依赖来自 `external/desktop-in-docker`，固定到本仓库记录的提交。其构建接收选定的系统、版本、桌面、时区和镜像源设置，在临时副本中运行，不读取子模块的 `.env`，也不修改其检出目录。

Android 镜像引用同一次构建先前生成的精确时间戳桌面标签。依赖构建失败会停止整个链路。

```sh
# Build the image
python3 scripts/build-image.py -b

# China mirror variant
python3 scripts/build-image.py -b --cn-mirror

# Eclipse Temurin instead of OpenJDK
python3 scripts/build-image.py -b --jdk-provider temurin

# Select a base system and version
python3 scripts/build-image.py -b -s ubuntu -v noble
python3 scripts/build-image.py -b -s fedora -v 43
# Fedora 44 requires Temurin for JDK 21, or a system OpenJDK 25 selection:
python3 scripts/build-image.py -b -s fedora -v 44 --jdk-provider temurin
```

默认使用 Debian `trixie`、Xfce 和 OpenJDK 21。Debian、Ubuntu、Fedora 和 Alpine 构建受固定版本桌面项目支持组合的约束。其当前 X11 构建拒绝 Arch 和高于 24.04 的 Ubuntu 版本，包括 `resolute`。Alpine 使用 musl，添加要求 glibc 的工具前先检查兼容性。

## Android SDK 与模拟器

`external/android-profile` 子模块固定到提交 `2d85cdc`。容器启动时，Supervisor 依次安装 SDK、创建 AVD 并启动模拟器。SDK 配置安装命令行工具、platform-tools 和 emulator；AVD 创建下载 profile 选定的系统镜像。这些下载在运行时进行，而非 Docker 构建期间。

`sdk_data` 持久保存 `/home/<user>/Android/Sdk`，`avd_data` 持久保存 `/home/<user>/.android/avd`。两者都是 Compose 管理的命名卷。在 Dev Container 中复用 Features 的项目需要自行配置持久化。

默认 profile 为 `/home/<user>/android-profiles/android.profile`。可设置 `ANDROID_PROFILE` 选择其他 profile，并将文件绑定挂载到容器。它定义系统镜像包前缀、设备定义、显示和模拟器参数。上游脚本按容器架构选择镜像 ABI。模拟器输出位于 `logs/android_stdout.log` 和 `logs/android_stderr.log`。

硬件加速需要可用的 KVM 设备和相应访问权限。Android Linux 模拟器要求 glibc，因此 Alpine 不受支持。安装 SDK 工具不等于已经验证每种架构和 profile 都能成功启动。

### KVM 加速

`kvm` Feature 保留原有用户组配置：复用或创建 GID 为 `992` 和 `993` 的组（`hostkvm1` 和 `hostkvm2`），并将容器用户加入其中。宿主 KVM 组 ID 不同时，需要匹配容器权限。

`python3 scripts/build-image.py -S` 自动加载 `docker/compose/docker-compose.kvm.yml`，映射 `/dev/kvm`。在 Dev Container 中复用 Features 的项目必须自行配置设备映射。无需设置 `KVM_GID` 或使用特权模式。模拟器加速设置由 Android profile 控制。

手动启动：

```sh
docker compose --env-file .env \
  -f docker/compose/docker-compose.yml \
  -f docker/compose/docker-compose.kvm.yml up -d
```

将 `IMAGE_REF` 设置为完整构建镜像引用（仓库及标签），例如 `android-in-docker:debian-trixie-xfce-openjdk21-snapshot`。宿主没有 `/dev/kvm` 时，只使用基础 Compose 文件，并在 profile 中配置软件加速。

## 发布

在 `.env` 中将 `DOCKER_USERNAME` 设置为镜像仓库命名空间，使用 `docker login` 认证，然后运行：

```sh
python3 scripts/build-image.py -P -m --latest
```

发布会构建并推送 `linux/amd64` 和 `linux/arm64` 镜像。桌面依赖先于 Android 镜像发布，使用相同命名空间和时间戳。`-m` 不会让普通 `-b` 构建变成多平台构建。

## 配置与标签

`.env` 示例：

```dotenv
DOCKER_USERNAME="storytellerf"
VNC_PASSWD="change-this-password"
IMAGE_TAG_TIME="20261007120000"
OPENJDK_VERSION="21"
```

`IMAGE_TAG_TIME` 选择时间戳标签。已有有效值会跨构建复用，`-c` 会刷新它。未配置命名空间时，本地镜像使用不带命名空间的仓库名。

Android 镜像标签格式：

```text
<system>-<version>-<desktop>-<jdk-provider><jdk-version>[-cn]-<label>
```

示例：

- `debian-trixie-xfce-openjdk21-snapshot`
- `debian-trixie-xfce-openjdk21-cn-latest`
- `debian-trixie-xfce-openjdk21-20261007120000`
- `debian-trixie-xfce-temurin21-snapshot`

每次构建都生成时间戳标签。默认启用 `snapshot` 别名；`--latest` 添加 `latest` 别名，`--no-snapshot` 禁用 snapshot 别名。短别名还可省略默认字段，例如 `snapshot`、`cn-snapshot` 和 `temurin21-snapshot`。

## 命令行选项

| 选项 | 说明 |
| --- | --- |
| `-b, --build` | 本地构建桌面依赖和 Android 镜像 |
| `-S, --start` | 启动选定的 Compose 环境 |
| `-T, --stop` | 停止并移除项目容器 |
| `-P, --publish` | 构建并推送多平台镜像及其依赖 |
| `-m, --multi-arch` | 多架构模式，与发布一起使用 |
| `-c, --create-env` | 交互创建或更新 `.env` |
| `-s, --system <system>` | 选择基础系统；限制见上文 |
| `-v, --version <version>` | 选择基础系统版本 |
| `-d, --desktop <xfce\|lxqt\|mate>` | 选择桌面，默认 `xfce` |
| `--jdk-provider <openjdk\|temurin>` | 选择 JDK 提供方，默认 `openjdk` |
| `-j, --jdk-version <version>` | 选择 JDK 主版本，默认 `21` |
| `-p, --password <password>` | 设置 VNC 密码 |
| `-z, --timezone <timezone>` | 设置时区；未设置时从宿主检测 |
| `--cn-mirror` | 启用中国镜像源和 `cn` 标签 |
| `--no-cn-mirror` | 禁用中国镜像源选择 |
| `--latest` | 添加 `latest` 标签 |
| `--no-snapshot` | 禁用 `snapshot` 标签 |
| `-h, --help` | 显示命令帮助 |

两个镜像源参数都未提供时，根据选定时区自动选择。

启用 Bash 补全：

```sh
source scripts/completion.bash
android-build --help
```

## Compose 与开发容器

`docker/compose/docker-compose.yml` 定义所有服务和端口、SSH 授权密钥、日志、SDK/AVD 存储、shell 历史和开发缓存。默认启用全部功能。镜像标签不再包含 `-dev` 后缀，也不再接受 `-D` / `--dev`。

用于其他项目时，直接配置其 Dev Container，并选择 [Features 参考](features/README.md) 中介绍的可复用 Features。

## 日志与诊断

Supervisor 日志挂载在 `./logs`：

```sh
tail -f ./logs/appium_stdout.log ./logs/appium_stderr.log
docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml ps
docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml exec android bash
docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml exec android supervisorctl status
```

使用非默认镜像标签、命名空间或主目录时，保留构建脚本保存的 `IMAGE_REF` 和 `CONTAINER_HOME`。Compose 不再使用 `IMAGE_TAG`。

自动检测端口并打开本地 VNC 客户端：

```sh
./scripts/open-vnc.sh
```

## 仓库布局

| 路径 | 用途 |
| --- | --- |
| `scripts/build-image.py` | 构建、发布、启动和停止入口 |
| `scripts/add-ssh-key.sh` | 向 Dev Container 授权密钥添加公钥 |
| `scripts/open-vnc.sh` | 检测 VNC 端口并启动本地客户端 |
| `base-scripts/` | Appium 启动及 SDK/AVD/模拟器启动顺序 |
| `docker/Dockerfile` | 直接调用工具安装器的镜像构建 |
| `features/` | 可复用的 Java、Node.js、Python、SSH、KVM 和 Appium Features |
| `docker/compose/` | 统一 Compose 配置 |
| `docker/config/supervisor/` | 容器服务配置 |
| `docker/config/appium/` | Appium capabilities 示例 |
| `external/desktop-in-docker/` | 固定版本的上游桌面源码子模块 |
| `external/android-profile/` | 固定版本的 SDK 安装、AVD 创建、启动脚本和 profile |
| `tests/test_build_orchestration.py` | 使用模拟 Docker 的构建编排测试 |
| `tests/smoke_features.py` | 真实工具、虚拟环境和 KVM 安装器测试 |
| `tests/test_android_startup.py` | SDK/AVD/模拟器启动顺序与失败处理 |

## Dev Container Features

工具安装器位于 `features/`，旁边的 `devcontainer-feature.json` 元数据用于在其他 Dev Container 中复用。本仓库 Docker 构建直接调用安装脚本。各安装器内部选择来源：Java、Node.js 和 Python 支持根据环境变量和时区自动选择来源，也支持明确覆盖来源。Python 在 PyPI 和 TUNA 镜像之间切换 pip。Node.js 使用项目维护的脚本安装 NVM 和 Node；Python、pip、virtualenv 和 pipx 来自发行版包。不需要内置 Dev Container 安装器。

`docker/Dockerfile` 按 Java、Node.js（含 npm registry 配置）、Python、SSH、KVM 权限和 Appium 的顺序安装。Debian/Ubuntu 和 Fedora 镜像还安装 VS Code。Android 环境准备使用固定版本子模块。选项和复用说明见 [Features 参考](features/README.md)。

构建脚本先构建固定版本桌面源码，再对最终镜像运行 `docker build`，生成时间戳、snapshot、latest 和短标签。镜像发布使用 `docker buildx build --platform linux/amd64,linux/arm64 --push`。构建本仓库要求宿主安装 Python 3.10+ 和 Bash，不需要 Node.js 或 Dev Container CLI。

Dockerfile 直接从固定版本的 `external/android-profile` 子模块复制 SDK/AVD 脚本和 profile，同时复制项目启动脚本和 Supervisor 配置。Appium 包含 UiAutomator2 和 storage/inspector 插件。SDK/AVD 环境准备、数据持久化、KVM 设备映射和 Compose 启动保留既有行为。

贡献者验证说明见 [DEVELOPMENT.md](DEVELOPMENT.md)。
