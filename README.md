# Android in Docker

A containerized desktop and Java development environment with Appium for Android automation. Every image provides noVNC, VNC, a JDK, Appium, SSH, and Git. Debian/Ubuntu and Fedora images also install VS Code. There is one image configuration; no separate standard or development mode is required.

Android SDK installation, AVD creation and startup, Android Studio installation, and Docker-in-Docker are no longer included. Configure your own Android SDK and target devices when using Appium for Android tests.

## Requirements

- Docker Engine and Docker Compose v2.
- Git with submodule support and Bash.
- Docker Buildx and registry access for multi-platform publishing.
- Internet access for downloading build dependencies.

The default Compose configuration does not require privileged mode or `/dev/kvm`.

## Quick start

Run commands from the repository root. Initialize the pinned desktop source dependency:

```sh
git submodule update --init --recursive
```

Create or update `.env` interactively:

```sh
./scripts/build-image.sh -c
```

Set `DOCKER_USERNAME` to your image namespace in `.env`. The build script uses it for both image builds and Compose startup. The supplied Compose file defaults to `storytellerf` when no namespace is set.

Build and start the environment:

```sh
mkdir -p data
touch data/authorized_keys
./scripts/build-image.sh -b -S
```

Add your SSH public key to `data/authorized_keys` before connecting to the environment. Password authentication is disabled.

Docker assigns host ports automatically. The script prints connection addresses after startup. Available services are:

| Service | Container port | Connection |
| --- | --- | --- |
| noVNC | 6080 | `http://localhost:<port>/vnc.html` |
| VNC | 5901 | `localhost:<port>` |
| Appium / Inspector | 4723 | `http://localhost:<port>/inspector` |
| SSH | 22 | `ssh -p <port> debian@localhost` |

The SSH username depends on the base system. Debian uses `debian`, Ubuntu uses `ubuntu`, Fedora uses `user`, and Alpine uses `alpine`.

Start an existing image without building, or stop the environment:

```sh
./scripts/build-image.sh -S
./scripts/build-image.sh -T
```

## Building images

The build order is:

```text
desktop base layer → desktop image → Android development image
```

The desktop dependency comes from `external/desktop-in-docker`, pinned to the commit recorded by this repository. Its build receives the selected system, version, desktop, timezone, and mirror settings. It runs in a temporary copy, without reading the submodule's `.env` or modifying its checkout.

The Android image references the exact timestamped desktop tag produced earlier in the same build. A failed dependency build stops the chain.

```sh
# Build the image
./scripts/build-image.sh -b

# China mirror variant
./scripts/build-image.sh -b --cn-mirror

# Eclipse Temurin instead of OpenJDK
./scripts/build-image.sh -b --jdk-provider temurin

# Select a base system and version
./scripts/build-image.sh -b -s ubuntu -v noble
./scripts/build-image.sh -b -s fedora -v 44
```

Defaults are Debian `trixie`, Xfce, and OpenJDK 21. Debian, Ubuntu, Fedora, and Alpine builds are subject to the pinned desktop project's supported combinations. Its current X11 build rejects Arch and Ubuntu versions newer than 24.04, including `resolute`. Alpine uses musl; check compatibility before adding tools that require glibc.

## Publishing

Set `DOCKER_USERNAME` in `.env` to your registry namespace and authenticate with `docker login`, then run:

```sh
./scripts/build-image.sh -P -m --latest
```

Publishing builds and pushes `linux/amd64` and `linux/arm64` images. Desktop dependencies are published before Android images, using the same namespace and timestamp. The `-m` flag does not make an ordinary `-b` build multi-platform.

## Configuration and tags

Example `.env`:

```dotenv
DOCKER_USERNAME="storytellerf"
VNC_PASSWD="change-this-password"
IMAGE_TAG_TIME="20261007120000"
OPENJDK_VERSION="21"
```

`IMAGE_TAG_TIME` selects the timestamp label. A valid existing value is reused across builds; `-c` refreshes it. Without a configured namespace, local images use unqualified repository names.

Android image tags have this form:

```text
<system>-<version>-<desktop>-<jdk-provider><jdk-version>[-cn]-<label>
```

Examples:

- `debian-trixie-xfce-openjdk21-snapshot`
- `debian-trixie-xfce-openjdk21-cn-latest`
- `debian-trixie-xfce-openjdk21-20261007120000`
- `debian-trixie-xfce-temurin21-snapshot`

Every build receives a timestamp tag. `snapshot` aliases are enabled by default; `--latest` adds `latest` aliases, and `--no-snapshot` disables snapshot aliases. Default fields may also be omitted in short aliases such as `snapshot`, `cn-snapshot`, and `temurin21-snapshot`.

## Command-line options

| Option | Description |
| --- | --- |
| `-b, --build` | Build the desktop dependency and Android image locally |
| `-S, --start` | Start the selected Compose environment |
| `-T, --stop` | Stop and remove project containers |
| `-P, --publish` | Build and push multi-platform images and their dependencies |
| `-m, --multi-arch` | Multi-architecture mode; use with publishing |
| `-c, --create-env` | Create or update `.env` interactively |
| `-s, --system <system>` | Select the base system; see build limitations above |
| `-v, --version <version>` | Select the base system version |
| `-d, --desktop <xfce\|lxqt\|mate>` | Select the desktop; default `xfce` |
| `--jdk-provider <openjdk\|temurin>` | Select the JDK provider; default `openjdk` |
| `-j, --jdk-version <version>` | Select the JDK major version; default `21` |
| `-p, --password <password>` | Set the VNC password |
| `-z, --timezone <timezone>` | Set the timezone; otherwise detect it from the host |
| `--cn-mirror` | Enable China mirrors and `cn` tags |
| `--no-cn-mirror` | Disable China mirror selection |
| `--latest` | Add `latest` tags |
| `--no-snapshot` | Disable `snapshot` tags |
| `-h, --help` | Show command help |

Mirror selection is automatic when neither mirror flag is supplied and uses the selected timezone.

Enable Bash completion:

```sh
source scripts/completion.bash
```

## Compose and development containers

`docker/compose/docker-compose.yml` defines all services and ports, SSH authorized keys, logs, shell history, and development caches. All features are enabled by default. Image tags no longer carry a `-dev` suffix, and `-D` / `--dev` are no longer accepted.

To generate a Dev Container configuration in another project, run this script from that project's root:

```sh
/path/to/android-in-docker/scripts/setup-devcontainer.sh
```

Adjust the generated `.devcontainer/dev.Dockerfile` image reference to match your namespace and published image tag. To add an SSH key:

```sh
cd .devcontainer
/path/to/android-in-docker/scripts/add-ssh-key.sh
```

## Logs and diagnostics

Supervisor logs are mounted under `./logs`:

```sh
tail -f ./logs/appium_stdout.log ./logs/appium_stderr.log
docker compose -f docker/compose/docker-compose.yml ps
docker compose -f docker/compose/docker-compose.yml exec android bash
docker compose -f docker/compose/docker-compose.yml exec android supervisorctl status
```

When using non-default image tags, namespaces, or home directories, retain the `IMAGE_TAG`, `DOCKER_USERNAME`, and `CONTAINER_HOME` values selected by the build script.

Open a local VNC client with automatic port detection:

```sh
./scripts/open-vnc.sh
```

Validate the build orchestration using a fake Docker executable, without building images or starting containers:

```sh
./tests/verify-fake-docker.sh
```

These checks cover supported build combinations, image dependency order, publishing, and Compose commands. They do not verify that a real image builds or runs successfully.

## Repository layout

| Path | Purpose |
| --- | --- |
| `scripts/build-image.sh` | Build, publish, start, and stop entry point |
| `scripts/setup-devcontainer.sh` | Generate Dev Container files |
| `scripts/add-ssh-key.sh` | Add a public key to Dev Container authorized keys |
| `scripts/open-vnc.sh` | Detect the VNC port and launch a local client |
| `base-scripts/` | Install and start Appium |
| `docker/dockerfiles/android/` | Unified image Dockerfile templates |
| `docker/fragments/` | Java, Node.js, npm, SSH, development tools, and editor fragments |
| `docker/compose/` | Unified Compose configuration |
| `docker/config/supervisor/` | Container service configuration |
| `docker/config/appium/` | Example Appium capabilities |
| `external/desktop-in-docker/` | Pinned upstream desktop source submodule |
| `tests/verify-fake-docker.sh` | Build orchestration smoke tests |

## Dockerfile fragments

Image templates live in `docker/dockerfiles/`; reusable installation fragments live in `docker/fragments/`. Files ending in `.dockerfile.inc` contain Dockerfile instructions and are included by the build script rather than built separately.

```text
docker/fragments/
├── java/
│   ├── openjdk/<system>.dockerfile.inc
│   └── temurin/
│       ├── <system>.dockerfile.inc
│       └── china/<system>.dockerfile.inc
├── nodejs/
│   ├── default/<system>.dockerfile.inc
│   └── china/<system>.dockerfile.inc
├── npm/
│   └── china.dockerfile.inc
├── development-tools/<system>.dockerfile.inc
├── ssh/
│   ├── <system>.dockerfile.inc
│   └── configure.dockerfile.inc
└── vscode/<system>.dockerfile.inc
```

Java fragments install the selected JDK. Node.js fragments install Node.js and npm, using regional download settings when selected. The separate npm fragment configures registry mirrors for root and the container user after Node.js is installed.

Each system-specific installer declares its own arguments, environment, and root user. Ubuntu reuses the Debian installers. The build script injects Java, Node.js, optional npm configuration, development tools, SSH installation and configuration, and VS Code where supported at `__INJECT_INSTALL_FRAGMENTS__`. SSH package installation is system-specific; service registration and authentication settings are shared. The image template then selects its runtime user and installs Appium.
