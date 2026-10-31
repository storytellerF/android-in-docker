# Local Dev Container Features

Each directory contains a `devcontainer-feature.json` and executable `install.sh`. Installers detect Debian/Ubuntu, Fedora, Arch, or Alpine and install their own prerequisites. Android emulator execution requires glibc; Alpine can install tools but cannot run the Linux emulator.

| Feature | Options | Behavior |
| --- | --- | --- |
| `java` | `provider`, `version`, `source`, `timezone` | OpenJDK or Temurin; defaults to OpenJDK 21 |
| `nodejs` | `source`, `timezone`, `registry` | Node.js and npm through NVM; project-maintained NVM installation on Debian/Ubuntu/Fedora/Arch, China Node mirror support, distro packages on Alpine |
| `python` | `source`, `timezone`, `indexUrl` | Python 3, pip, virtualenv, and pipx from distribution packages |
| `ssh` | — | OpenSSH, key authentication, startup script, and Supervisor service |
| `appium` | `version` | Appium server, UiAutomator2 driver, storage/inspector plugins |
| `kvm` | — | Reuse/create GIDs 992 and 993 and add the selected user |

Features use the Dev Container-provided `_REMOTE_USER` and `_REMOTE_USER_HOME`, derived from `remoteUser`, for user-specific configuration. They expect an existing user. SSH service integration targets the desktop-in-docker image, which supplies Supervisor and passwordless sudo for that user. KVM device mapping belongs in the consuming project's runtime configuration. Select the Java and Node.js Features before Appium and set `overrideFeatureInstallOrder` when using local Features.

This repository's Dockerfile calls the same `install.sh` scripts directly and supplies `_REMOTE_USER` from its `USERNAME` build argument. It declares runtime environment variables explicitly and does not resolve Feature metadata or registry references. The metadata remains available for other Dev Container projects. The Appium installer installs the server as root and the driver/plugins for the selected user. Android scripts/profiles come directly from the pinned `android-profile` submodule; SDK and AVD provisioning runs at container startup into persistent volumes.

For another local Dev Container, stage standalone Features (including their shared helper) into a new directory, then reference the selected Features in `devcontainer.json`:

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

These are local Features, not published registry references. No Feature publishing occurs during image publication.

## Project-maintained installers

The Node and Python installation scripts are maintained in this repository. Node downloads NVM and Node.js; Python uses distribution packages. The same scripts serve direct Docker builds and external Dev Container Features, without bundled copies of the official Dev Container installers.

Compatibility decisions:

- Java retains the existing OpenJDK/Temurin package installation, JDK version option, TUNA Temurin repositories, and Arch architecture selection. The selected JDK home comes from the requested package, so existing JDKs on `PATH` do not override the requested provider/version.
- Node retains NVM 0.40.3, the current Node release, China mirror selection, npm, shell initialization, and the existing NVM location. The NVM directory belongs to the selected user. If Corepack is already available, its shims are installed beside the NVM Node executable.
- Python retains pip and virtual environment support. Its source selection switches between PyPI and the TUNA PyPI mirror for pip operations and persists the selected index in global pip configuration. All supported distributions install Python, pip, virtualenv, and pipx through their package manager; no packages are installed into the system Python with pip.
- Git remains available in every project image through its Dockerfile; it is not a Feature.
- Desktop VS Code is installed by the project image prerequisite script on Debian/Ubuntu and Fedora; it is not published as a Feature.
- Node.js includes npm configuration: the China preset installs `nrm` and configures the Tencent registry for root and the remote user. An explicit `registry` option takes precedence during npm package installation and configuration, skips `nrm`, and does not temporarily switch npm to other registries.
- SSH retains key-only authentication and Supervisor service management, rather than introducing the official SSH Feature's separate entrypoint.
- KVM retains GIDs 992/993. The project image retains pinned profile scripts, SDK/AVD paths, and Supervisor-managed emulator startup. The Appium Feature installs the server, driver, and plugins; Appium is started manually rather than by Supervisor.

For an installer update, run configuration tests and actual installation checks for the affected distributions. See [development validation](../DEVELOPMENT.md#validation).

## Automatic source selection

Java, Node.js, and Python default to `source: "auto"`. Preset choices are `default` and `china`; mirror selection stays inside each Feature.

Selection priority:

1. An explicit `source` option.
2. A per-tool build environment variable (`JAVA_SOURCE`, `NODEJS_SOURCE`, or `PYTHON_SOURCE`), then `FEATURE_SOURCE`.
3. The `timezone` option, `TZ`, `/etc/timezone`, or `/etc/localtime`.

Mainland China timezone identifiers select China mirrors; other timezones select the default source. `source: "default"` explicitly disables China mirrors.

Feature installers run while building the image. Host variables and `containerEnv`/`remoteEnv` are not automatically available during that phase. Pass host selections through Feature options, for example:

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

Set `TZ=Asia/Shanghai` for automatic China selection, `PYTHON_SOURCE=default` to force PyPI, or `PYTHON_INDEX_URL=https://your-mirror.example/simple` for another index. Use `${localEnv:FEATURE_SOURCE:auto}` in the `source` option to share a host selection across tools.

Python uses PyPI (`https://pypi.org/simple`) or TUNA (`https://pypi.tuna.tsinghua.edu.cn/simple`). A non-empty `indexUrl` overrides the preset; build environment `PYTHON_INDEX_URL` or `PIP_INDEX_URL` can also specify an index. The selected HTTPS index is used during installation and persisted in `/etc/pip.conf` for users and virtual environments. TLS verification remains enabled.

The existing build script passes its resolved source explicitly to each Feature, preserving `--cn-mirror` and `--no-cn-mirror` behavior.

## Publish to GHCR

The `Publish Dev Container Features` workflow runs when Feature sources or publishing configuration change on `main`, and can also be started manually from the Actions tab. It uses `GITHUB_TOKEN` with `packages: write`; no personal token secret is required.

Packages are published under `ghcr.io/<repository-owner>/<repository-name>/<feature-id>`. The release staging script rewrites collection-local `installsAfter` references to the actual repository namespace, supporting both the upstream repository and forks without changing source metadata. Only directories in `features/` are published; Android profiles and emulator scripts remain in the submodule.

Each Feature's `version` field determines its release version and major-version tag. Increment it when publishing changes to an existing release. For public reuse, set the packages to Public in GitHub Packages after initial publication, and ensure the repository's Actions token has write access to existing packages. This workflow publishes Feature packages, not Android images.
