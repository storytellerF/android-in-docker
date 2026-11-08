# 开发

## 构建架构

`scripts/build-image.py` 先构建固定版本桌面依赖，再通过 Docker 构建 `docker/Dockerfile`。选定的桌面镜像、用户名、Java 提供方和版本、镜像来源通过构建参数传入。发布通过 Buildx 的 `--push` 支持两种架构。入口要求 Python 3.10+ 和 Bash；镜像构建不需要 Dev Container CLI 或宿主 Node.js。

Dockerfile 按依赖顺序以 root 运行共享的 `features/*/install.sh`，通过 `_REMOTE_USER` 传递用户专用配置。Java、Node、Python 和 SDK 运行路径通过 `ENV` 声明；Feature 元数据只由外部 Dev Container 用户使用。修改运行路径时，同时更新 Dockerfile 和对应 Feature 元数据。

Debian/Ubuntu、Fedora 和 Arch 共用一套 NVM 实现安装 Node，在安装前应用来源选择。Alpine 使用发行版 Node.js 包。所有支持系统上的 Python 都使用发行版包，并在 `/usr/local/python/current/bin` 暴露稳定的 Python/pip 别名。选定用户拥有 `/usr/local/py-utils`，可以不使用 root 安装 pipx 应用。没有内置 `devcontainers/features` 安装器副本。

Python 入口将 CLI、环境和字面量 `.env` 值解析为不可变 `BuildConfig`（`scripts/build_config.py`）。优先级为 CLI、进程环境、已保存值，不把 `.env` 当作 shell 代码执行。Dotenv 写入器使用双引号值，并转义反斜杠、引号和美元符号；Python 和真实 Compose 往返测试覆盖相同字面量。构建执行、桌面依赖暂存和 Compose 操作都使用该配置。构建成功后原子记录 `IMAGE_REF` 及其配置；启动在创建容器前验证 Compose 插值与该引用一致。`--config` 选择其他配置文件，`--project-name` 隔离 Compose 栈。

构建配方解析、最终构建验证和运行目标选择是独立阶段。CLI 和交互式配方共享 `validate_build_config`，在提示结束后、保存或调用 Docker 前执行。拒绝的编辑不改变旧文件。纯运行命令通过 `RuntimeConfig` 使用记录的 `IMAGE_REF`、`CONTAINER_HOME` 和 `CONTAINER_USER`，不应用当前安装可用性规则。显式镜像选择参数从配方字段解析其他引用；没有 `IMAGE_REF` 的旧文件仍能解析其记录的标签。运行时覆盖时区或密码会保留记录的镜像。

各发行版 Java 适配器管理包名、包查询和选定 JDK 路径。通过 `JDK_HOME_FILE` 记录权威 home，共享入口只验证并启用。RPM 适配器使用 `--noghost` 查询，`record-home.sh` 排除全局 alternatives 链接。

`features/_common/source-selection.sh` 是唯一维护的来源选择实现。仓库构建直接读取它；Feature 发布暂存时复制到每个可独立安装的 Feature 中。SSH 启动和 Supervisor 配置只位于 `features/ssh/`。

## 验证

测试运行器使用 Python 标准库 `unittest`。执行正式 shell 脚本需要 Bash：

```sh
python3 tests/test_build_config.py
python3 tests/test_build_orchestration.py
python3 tests/test_feature_packaging.py
python3 tests/test_java_home.py
python3 tests/test_compose_config.py
python3 tests/test_android_startup.py
python3 tests/test_feature_sources.py
```

模拟 Docker 检查覆盖支持的构建组合、镜像依赖顺序、发布参数和 Compose 命令，不实际构建镜像。

真实安装测试直接使用 Docker，并下载工具包：

```sh
python3 tests/smoke_features.py
NODEJS_CHINA_MIRROR=true PYTHON_CHINA_MIRROR=true python3 tests/smoke_features.py
```

冒烟测试以非 root 用户检查 Git、JDK 21、Node/npm/NVM、Python/pip/virtualenv、离线 pipx 应用安装、虚拟环境创建和 KVM 组复用，不启动 Android 模拟器，也不验证完整桌面镜像。

## Node.js Corepack 回归测试

安装 Docker 和 Python 3 后运行：

```sh
python3 tests/test_nodejs_system_corepack.py
```

测试先在 Debian 安装发行版提供的 Corepack，再为非 root 用户调用 Node.js 安装器。它验证安装器提供 Node 所需运行库，且系统 Corepack 无需 `/usr/bin` 写权限，就能在 NVM Node 可执行文件旁创建可执行 Yarn 和 pnpm shim。测试下载 Node.js，结束后删除临时镜像。

Node 安装实现在 `features/nodejs/install-nvm.sh`。它以选定用户安装 NVM 和 Node，包含平台运行库，并在选定 Node 可执行文件旁启用已有 Corepack。修改后运行此回归测试和 `python3 tests/smoke_features.py`。

## 安装器选择回归测试

```sh
python3 tests/test_java_selection.py
python3 tests/test_java_selection_fedora.py
python3 tests/test_npm_registry.py
```

Fedora 测试将全局 alternatives 保持为 JDK 25，同时选择由包提供的 JDK 21。默认 Fedora 基础版本为 43，因为 Fedora 44 [移除了系统 OpenJDK 21](https://fedoraproject.org/wiki/Changes/Java21RemovedEarlierThenScheduled)；Fedora 44 应选择 Temurin 21 或 OpenJDK 25。

Debian Java 测试先安装 OpenJDK，在已有 JDK 仍位于 `PATH` 时选择 Temurin，再重新选择 OpenJDK。每个生成镜像都必须通过 `JAVA_HOME` 运行请求提供方的 Java 和 javac。

npm 测试构建含 npm 和 sudo 的镜像，再禁用容器网络，分别为 root 和非 root 用户运行 registry 配置。全局和用户配置都必须包含明确指定的 registry。配置不得下载 `nrm` 或切换到预设 registry；只有未明确覆盖的中国预设才安装 `nrm`。

每项回归独立报告，即使失败也清理 Docker 镜像和容器。`tests/fake-bin/docker` 是 Python 命令记录器，其 JSON-lines 日志保留参数边界，包括带空格的路径。`tests/fixtures/android_step.py` 模拟 SDK/AVD 命令，不启动设备。

## Feature 发布

Feature 打包和 GHCR 发布与镜像构建相互独立。发布 workflow 安装 Dev Container CLI 0.87.0，并通过 `scripts/prepare-feature-release.py` 为目标命名空间暂存元数据。该发布 workflow 额外需要 Node.js。普通镜像构建和安装测试只使用 Python 3 和 Docker，不需要 Dev Container CLI。

## 正式镜像与 Compose 集成

先构建固定版本桌面镜像，或复用由该版本构建的本地镜像，再运行：

```sh
ANDROID_TEST_DESKTOP_IMAGE=desktop-in-docker:<pinned-build-tag> python3 tests/test_image_composition.py
```

测试调用真实 Python 构建入口并传入 `--desktop-image`，构建正式 `docker/Dockerfile`，渲染本地及带命名空间镜像引用的实际 Compose 配置，核对运行环境值与 Feature 元数据。它启动隔离 Compose 项目，验证已安装工具、noVNC 页面、SSH 密钥认证和 Appium 就绪。需要 Docker Compose 2.24+、KVM 映射、SSH 客户端、互联网和已初始化子模块。

此服务集成测试只禁用 Android Supervisor 程序；SDK/AVD 下载和模拟器启动另由固定版本 Android 项目和启动顺序测试覆盖。测试移除自己的容器、卷、镜像标签、密钥和临时配置。正式 Compose 不包含此覆盖配置，也不运行全局镜像清理。

共享运行路径也在 Feature 元数据中向外部使用者声明。正式集成检查两者一致，不把独立工具冒烟夹具视为完整镜像覆盖。发行版冒烟测试仍适用于安装器回归，但不能替代此集成检查。

真实 Python CLI 启停回归应在没有 `logs` 和 `data/authorized_keys` 的一次性检出目录中运行：

```sh
ANDROID_TEST_RUNTIME_IMAGE=android-in-docker:<verified-debian-tag> python3 tests/test_runtime_commands.py
```

此检查将已有镜像与已停用的 Fedora 44/OpenJDK 21 配方元数据一起记录，再通过真实 Python 入口启动和停止。它保留镜像记录的用户和 home，检查精确选定镜像及字面量密码，只在测试镜像中禁用 Android 启动，并清理隔离的 Compose 项目、临时绑定源和镜像标签。已有日志或密钥路径时会拒绝替换。

## VNC 客户端配置回归

`scripts/open-vnc.sh` 调用 `scripts/read-vnc-password.py`，后者使用共享 `read_env` 解码器。它保留字面量美元符号、反斜杠和引号，支持旧 `VNC_PASSWORD` 别名，解析配置失败时在启动客户端前停止。密码通过 `printf` 传递给编码器。

```sh
python3 tests/test_vnc_config.py
VNC_TEST_ENCODER_IMAGE=android-in-docker:<verified-debian-tag> python3 tests/test_vnc_config.py
```

启动器测试使用隔离命令适配器，记录编码器的精确输入，检查 viewer 参数及密码文件权限，不打开 GUI。提供镜像选项时，真实 TigerVNC 编码器在一次性离线容器中运行，其输出与直接编码原始密码的结果比较。需要 Bash 和标准 Unix 工具。
