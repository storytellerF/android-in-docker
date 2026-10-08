# Android in Docker

A containerized desktop and Java development environment with Appium for Android automation. Every image provides noVNC, VNC, a JDK, Node.js, Python, Appium, SSH, and Git. Debian/Ubuntu and Fedora images also install VS Code. There is one image configuration; no separate standard or development mode is required.

Android SDK installation, AVD creation, and emulator startup are provided by the pinned `android-profile` submodule. Android Studio installation and Docker-in-Docker are not included.

## Requirements

- Docker Engine and Docker Compose v2.
- Git with submodule support, Bash, and Python 3 on the build host.
- Node.js and the Dev Container CLI (`npm install -g @devcontainers/cli@0.87.0`).
- Docker Buildx and registry access for multi-platform publishing.
- Internet access for downloading build dependencies.

The build script maps `/dev/kvm` when starting containers; privileged mode is not required.

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
| Appium / Inspector | 4723 | `http://localhost:<port>/inspector` after manual startup |
| Emulator ADB | 5555 | Availability depends on the emulator profile and network binding |
| SSH | 22 | `ssh -p <port> debian@localhost` |

Appium is installed but is not started by Supervisor. Start it manually inside the container when needed:

```sh
~/bin/start-appium.sh
# Or: appium --use-plugins=storage,inspector --allow-cors
```

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

## Android SDK and emulator

The `external/android-profile` submodule is pinned to commit `2d85cdc`. At container startup, Supervisor runs SDK installation, AVD creation, and emulator startup in that order. SDK setup installs command-line tools, platform-tools, and the emulator; AVD creation downloads the system image selected by the profile. These downloads occur at runtime, not during the Docker build.

`sdk_data` persists `/home/<user>/Android/Sdk`, and `avd_data` persists `/home/<user>/.android/avd`. Both are Compose-managed named volumes. The generated Dev Container configuration includes the same volumes.

The default profile is `/home/<user>/android-profiles/android.profile`. Set `ANDROID_PROFILE` to select another profile, and bind-mount that file into the container. It defines the system-image package prefix, device definition, display, and emulator arguments. The upstream scripts select the image ABI from the container architecture. Emulator output appears in `logs/android_stdout.log` and `logs/android_stderr.log`.

Hardware acceleration requires a usable KVM device and matching access permissions. Android's Linux emulator requires glibc, so Alpine is not a supported emulator runtime. Installing SDK tools does not establish that every architecture/profile can boot successfully.

### KVM acceleration

The `kvm` Feature restores the original user group setup: it reuses or creates groups with GIDs `992` and `993` (`hostkvm1` and `hostkvm2`) and adds the container user to them. Hosts using a different KVM group ID need matching container permissions.

`build-image.sh -S` automatically loads `docker/compose/docker-compose.kvm.yml` to map `/dev/kvm`. The generated Dev Container configuration also maps this device. No `KVM_GID` setting or privileged mode is required. Emulator acceleration settings are controlled by the Android profile.

For manual startup:

```sh
docker compose --env-file .env \
  -f docker/compose/docker-compose.yml \
  -f docker/compose/docker-compose.kvm.yml up -d
```

Select your built `IMAGE_TAG` when it differs from the default snapshot tag. For hosts without `/dev/kvm`, use only the base Compose file and configure software acceleration in your profile.

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

`docker/compose/docker-compose.yml` defines all services and ports, SSH authorized keys, logs, SDK/AVD storage, shell history, and development caches. All features are enabled by default. Image tags no longer carry a `-dev` suffix, and `-D` / `--dev` are no longer accepted.

For another project, configure its Dev Container directly and select the reusable Features described in [the Features reference](features/README.md).

## Logs and diagnostics

Supervisor logs are mounted under `./logs`:

```sh
tail -f ./logs/appium_stdout.log ./logs/appium_stderr.log
docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml ps
docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml exec android bash
docker compose -f docker/compose/docker-compose.yml -f docker/compose/docker-compose.kvm.yml exec android supervisorctl status
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
| `scripts/add-ssh-key.sh` | Add a public key to Dev Container authorized keys |
| `scripts/open-vnc.sh` | Detect the VNC port and launch a local client |
| `base-scripts/` | Appium installation/startup and the SDK/AVD/emulator startup sequence |
| `docker/dockerfiles/default/` | Unified image Dockerfile templates |
| `features/` | Reusable Features for Java, Node.js, Python, npm, SSH, VS Code, KVM, and Appium |
| `docker/compose/` | Unified Compose configuration |
| `docker/config/supervisor/` | Container service configuration |
| `docker/config/appium/` | Example Appium capabilities |
| `external/desktop-in-docker/` | Pinned upstream desktop source submodule |
| `external/android-profile/` | Pinned SDK installation, AVD creation, startup scripts, and profiles |
| `tests/verify-fake-docker.sh` | Build orchestration smoke tests |
| `tests/smoke-features.sh` | Real tool/virtual environment/KVM Feature build test |
| `tests/test-android-startup.sh` | SDK/AVD/emulator startup order and failure handling |

## Dev Container Features

Reusable tool installation is implemented as local Dev Container Features in `features/`, each with `devcontainer-feature.json` and `install.sh`. There is no Dockerfile fragment injection. Every Feature installs the packages it requires. Source selection happens inside the Feature: Java, Node.js, and Python default to automatic source selection from build environment variables and timezone, with explicit `source` overrides. Python switches pip between PyPI and the TUNA mirror. Existing official Node.js and Python installers are reused where compatible, with their version and source revision recorded under each Feature’s `upstream/` directory.

Java, Node.js, optional npm registry configuration, Python, SSH, VS Code (where supported), KVM permissions, and Android/Appium are installed in the generated configuration's explicit order. Ubuntu shares Debian installers. See [the Features reference](features/README.md) for options and reuse instructions.

The build script first builds the pinned desktop source. It then stages Features and generates `build/.devcontainer/devcontainer.json`, based on the minimal templates in `docker/dockerfiles/default/`. The Dev Container CLI builds the final image with the existing timestamp, snapshot, latest, and short tags. Publishing uses `--platform linux/amd64,linux/arm64 --push`.

Install the CLI on the build host:

```sh
npm install -g @devcontainers/cli@0.87.0
```

The host also needs Python 3, Docker, and Buildx for multi-platform publication. Set `DEVCONTAINER_CLI` to use an alternate CLI executable. The generated configuration can be built directly after the desktop dependency exists:

```sh
devcontainer build --workspace-folder "$PWD/build" \
  --config "$PWD/build/.devcontainer/devcontainer.json" \
  --image-name android-in-docker:local --no-lockfile
```

The image templates copy SDK/AVD scripts and profiles directly from the pinned `external/android-profile` submodule, together with project startup scripts and Supervisor configuration. Appium installation runs after Node.js through the reusable `features/appium/` Feature, including UiAutomator2 and the storage/inspector plugins. The image template declares runtime SDK paths and ports. SDK/AVD provisioning, persisted data, KVM device mapping, and Compose startup retain their existing behavior.

Validation commands:

```sh
bash tests/verify-fake-docker.sh
bash tests/test-android-startup.sh
bash tests/test-feature-sources.sh
# Requires Docker and the Dev Container CLI; downloads tool packages.
bash tests/smoke-features.sh
# Exercise Python package installation using TUNA.
PYTHON_CHINA_MIRROR=true bash tests/smoke-features.sh
```

The smoke build checks Git, JDK 21, Node/npm/NVM, Python/pip/virtualenv, and KVM group reuse as the non-root user. It does not boot an Android emulator or validate the full desktop image.
