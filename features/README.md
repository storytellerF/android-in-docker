# 本地 Dev Container Features

每个目录包含 `devcontainer-feature.json` 和可执行的 `install.sh`。安装器检测 Debian/Ubuntu、Fedora、Arch 或 Alpine，并安装各自前提依赖。Android 模拟器执行要求 glibc；Alpine 能安装工具，但不能运行 Linux 模拟器。

| Feature | 选项 | 行为 |
| --- | --- | --- |
| `java` | `provider`、`version`、`source`、`timezone` | OpenJDK 或 Temurin，默认 OpenJDK 21 |
| `nodejs` | `source`、`timezone`、`registry` | 通过 NVM 安装 Node.js 和 npm；Debian/Ubuntu/Fedora/Arch 使用项目维护的 NVM 安装，支持中国 Node 镜像；Alpine 使用发行版包 |
| `python` | `source`、`timezone`、`indexUrl` | 通过发行版包安装 Python 3、pip、virtualenv 和 pipx |
| `ssh` | — | OpenSSH、密钥认证、启动脚本和 Supervisor 服务 |
| `appium` | `version` | Appium server、UiAutomator2 驱动、storage/inspector 插件 |
| `kvm` | — | 复用或创建 GID 992 和 993，并添加选定用户 |

Features 使用 Dev Container 根据 `remoteUser` 提供的 `_REMOTE_USER` 和 `_REMOTE_USER_HOME` 完成用户专用配置，要求用户已经存在。SSH 服务集成面向 desktop-in-docker 镜像，后者提供 Supervisor 和该用户的免密 sudo。KVM 设备映射属于使用方项目的运行配置。应在 Appium 前选择 Java 和 Node.js Features；本地 Features 使用 `overrideFeatureInstallOrder`。

本仓库 Dockerfile 直接调用相同 `install.sh`，从 `USERNAME` 构建参数提供 `_REMOTE_USER`。它明确声明运行环境变量，不解析 Feature 元数据或 registry 引用。元数据仍供其他 Dev Container 项目使用。Appium 安装器以 root 安装服务器，为选定用户安装驱动和插件。Android 脚本及 profile 直接来自固定版本 `android-profile` 子模块；SDK 和 AVD 在容器启动时准备并写入持久卷。

在其他本地 Dev Container 中，将独立 Features（含共享辅助程序）暂存到新目录，再在 `devcontainer.json` 引用所选 Features：

```sh
python3 scripts/prepare-feature-release.py --namespace example/android-in-docker --output .devcontainer/features
```

```json
{
  "image": "storytellerf/desktop-in-docker:debian-trixie-xfce-latest",
  "remoteUser": "debian",
  "features": {
    "./features/java": { "provider": "openjdk", "version": "21" },
    "./features/nodejs": {},
    "./features/python": {}
  },
  "overrideFeatureInstallOrder": [
    "./features/java", "./features/nodejs", "./features/python"
  ]
}
```

这些是本地 Features，不是已发布的 registry 引用。镜像发布不会同时发布 Feature。

## 项目维护的安装器

Node 和 Python 安装脚本在本仓库维护。Node 下载 NVM 和 Node.js，Python 使用发行版包。同一套脚本服务于直接 Docker 构建和外部 Dev Container Features，没有内置官方 Dev Container 安装器副本。

兼容性决策：

- Java 保留已有 OpenJDK/Temurin 包安装、JDK 版本选项、TUNA Temurin 仓库和 Arch 架构选择。选定 JDK home 来自请求的包，已有 `PATH` JDK 不会覆盖请求的提供方和版本。
- Node 保留 NVM 0.40.3、当前 Node 版本、中国镜像源选择、npm、shell 初始化和原有 NVM 位置。NVM 目录归选定用户所有。已有 Corepack 时，其 shim 安装在 NVM Node 可执行文件旁。
- Python 保留 pip 和虚拟环境支持。来源选择会为 pip 操作切换 PyPI 与 TUNA PyPI 镜像，并将选定 index 保存到全局 pip 配置。所有受支持发行版均通过包管理器安装 Python、pip、virtualenv 和 pipx，不通过 pip 向系统 Python 安装包。
- Git 继续由 Dockerfile 提供给每个项目镜像，不是 Feature。
- 桌面 VS Code 由项目镜像前提脚本在 Debian/Ubuntu 和 Fedora 安装，不作为 Feature 发布。
- Node.js 包含 npm 配置：中国预设安装 `nrm`，为 root 和远程用户配置腾讯 registry。明确的 `registry` 选项在 npm 包安装和配置时优先，跳过 `nrm`，不会临时将 npm 切换到其他 registry。
- SSH 保留仅密钥认证和 Supervisor 服务管理，不引入官方 SSH Feature 的独立入口。
- KVM 保留 GID 992/993。项目镜像保留固定版本 profile 脚本、SDK/AVD 路径和 Supervisor 管理的模拟器启动。Appium Feature 安装服务器、驱动和插件；Appium 手动启动，不由 Supervisor 启动。

更新安装器后，运行受影响发行版的配置测试和真实安装检查，见[开发验证](../DEVELOPMENT.md#验证)。

## 自动来源选择

Java、Node.js 和 Python 默认 `source: "auto"`。预设选项为 `default` 和 `china`，镜像源选择保留在各 Feature 内部。

选择优先级：

1. 明确的 `source` 选项。
2. 各工具构建环境变量（`JAVA_SOURCE`、`NODEJS_SOURCE` 或 `PYTHON_SOURCE`），然后是 `FEATURE_SOURCE`。
3. `timezone` 选项、`TZ`、`/etc/timezone` 或 `/etc/localtime`。

中国大陆时区标识选择中国镜像源，其他时区选择默认来源。`source: "default"` 明确禁用中国镜像源。

Feature 安装器在镜像构建时运行，宿主变量及 `containerEnv`/`remoteEnv` 不会自动在此阶段可用。通过 Feature 选项传递宿主选择，例如：

```json
{
  "features": {
    "./features/python": {
      "source": "${localEnv:PYTHON_SOURCE:auto}",
      "timezone": "${localEnv:TZ:}",
      "indexUrl": "${localEnv:PYTHON_INDEX_URL:}"
    }
  }
}
```

设置 `TZ=Asia/Shanghai` 自动选择中国来源，`PYTHON_SOURCE=default` 强制使用 PyPI，或 `PYTHON_INDEX_URL=https://your-mirror.example/simple` 指定其他 index。在 `source` 选项中使用 `${localEnv:FEATURE_SOURCE:auto}`，可让多个工具共用宿主选择。

Python 使用 PyPI（`https://pypi.org/simple`）或 TUNA（`https://pypi.tuna.tsinghua.edu.cn/simple`）。非空 `indexUrl` 覆盖预设；构建环境 `PYTHON_INDEX_URL` 或 `PIP_INDEX_URL` 也可指定 index。选定 HTTPS index 在安装期间使用，并保存到 `/etc/pip.conf` 供用户和虚拟环境使用。TLS 验证保持启用。

现有构建脚本将解析后的来源显式传给各 Feature，保留 `--cn-mirror` 和 `--no-cn-mirror` 行为。

## 发布到 GHCR

`Publish Dev Container Features` workflow 在 `main` 上 Feature 源码或发布配置变化时运行，也可从 Actions 页手动触发。使用具有 `packages: write` 权限的 `GITHUB_TOKEN`，无需个人令牌 secret。

包发布到 `ghcr.io/<repository-owner>/<repository-name>/<feature-id>`。发布暂存脚本将集合内 `installsAfter` 引用重写到实际仓库命名空间，无需修改源元数据即可支持上游和 fork。只发布 `features/` 中的目录；Android profile 和模拟器脚本仍位于子模块。

每个 Feature 的 `version` 字段决定发布版本和主版本标签。发布对已有版本的修改时应递增版本。供公众复用时，首次发布后在 GitHub Packages 将包设为 Public，并确保仓库 Actions 令牌有权写入已有包。此 workflow 发布 Feature 包，不发布 Android 镜像。
