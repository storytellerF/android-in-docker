# Android in Docker

提供一个在 Docker 容器中运行 Android Emulator、VNC（noVNC）和 Appium 的环境，方便进行自动化测试与调试。

## 快速开始

1. 如果还没有外部 SDK 卷（在 `docker-compose.yml` 中声明为 `sdk_data`），先创建它：

    ```sh
    docker volume create sdk_data
    ```

2. 使用脚本构建镜像（或用 docker-compose 构建）：

    ```sh
    ./build-image.sh
    # 或
    docker-compose build
    ```

    相关文件：[`build-image.sh`](build-image.sh) ，[`Dockerfile`](Dockerfile) ，[`docker-compose.yml`](docker-compose.yml)

3. 启动服务：

    ```sh
    docker-compose up -d
    ```

4. 连接与验证

    - noVNC（Web VNC）：<http://localhost:6080>  
    - 直接 VNC：5901（本地 client 连接 localhost:5901）  
    - ADB（端口映射）：5555（可用 `adb connect localhost:5555`）  
    - Appium：4723（Appium server）<http:localhost:4723/inspector>

## 主要文件与脚本

- 容器镜像与构建
  - [`Dockerfile`](Dockerfile)
  - [`build-image.sh`](build-image.sh)

- 启动脚本
  - 启动 Android Emulator: [`start-android.sh`](start-android.sh)（内部会调用 [`install-sdk.sh`](install-sdk.sh) 来确保 SDK 可用）
  - 启动 VNC: [`start-vnc.sh`](start-vnc.sh)
  - 启动 Appium: [`start-appium.sh`](start-appium.sh)

- Supervisor 管理：[`supervisord.conf`](supervisord.conf)（配置了 vnc / novnc / android / appium 四个 program）

- 自动化能力示例：[`appium-capability.json`](appium-capability.json)

- 环境与忽略
  - 环境变量文件：[` .env `](.env)
  - Git 忽略：[`.gitignore`](.gitignore)

## 卷与持久化

docker-compose 已配置以下卷（见 [`docker-compose.yml`](docker-compose.yml)）：

- avd_data: 保存 AVD（Android 虚拟设备）数据（映射到容器的 `/root/.android/avd`）
- sdk_data: 持久化 Android SDK（外部卷，需提前创建）

## 日志与调试

容器中 supervisor 日志映射到宿主目录 `./logs`（参见 [supervisord.conf](supervisord.conf) 和 [docker-compose.yml](docker-compose.yml)）。常用日志位置：

- 宿主：`./logs`（映射自容器 `/var/log/supervisor`）
- 容器内：`/var/log/supervisor/*.log`

## 常见操作

- 重建镜像并重启：

```sh
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

- 进入容器调试：

```sh
docker-compose exec android bash
```

- 通过 ADB 连接（宿主）：

```sh
adb connect localhost:5555
adb devices
```

查看supervisor 状态

```sh
sudo supervisorctl status
```

## 注意事项

- 若第一次启动，容器会自动下载并安装 Android SDK 命令行工具及必须组件（由 [`install-sdk.sh`](install-sdk.sh) 执行）；这一步可能较慢且需要网络访问 Google 仓库。
- `docker-compose.yml` 中将容器设置为 `privileged: true` 以启用 KVM 加速（仅在宿主支持并正确配置 KVM 时生效）。
- 如果需要改变 Java 版本，调整构建时参数或 `OPENJDK_VERSION`（见 [`Dockerfile`](Dockerfile) 与 [`build-image.sh`](build-image.sh)）。
