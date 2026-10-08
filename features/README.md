# Local Dev Container Features

Each directory contains a `devcontainer-feature.json` and executable `install.sh`. Installers detect Debian/Ubuntu, Fedora, Arch, or Alpine and install their own prerequisites. VS Code is supported on Debian/Ubuntu and Fedora. Android emulator execution requires glibc; Alpine can install tools but cannot run the Linux emulator.

| Feature | Options | Behavior |
| --- | --- | --- |
| `git` | — | Git, using the official installer on Debian/Ubuntu and Fedora |
| `java` | `provider`, `version`, `source`, `timezone` | OpenJDK or Temurin; defaults to OpenJDK 21 |
| `nodejs` | `source`, `timezone` | Node.js and npm through NVM; default Debian/Ubuntu/Fedora installs reuse the official installer, China builds preserve the Node mirror, Alpine uses distro packages |
| `npm` | `registry` | nrm and optional registry configuration for root and the selected user |
| `python` | `source`, `timezone`, `indexUrl` | Python 3, pip, and virtual environment support; official installer on Debian/Ubuntu/Fedora, distro packages on Alpine/Arch |
| `ssh` | — | OpenSSH, key authentication, startup script, and Supervisor service |
| `vscode` | — | Microsoft's desktop VS Code package |
| `kvm` | — | Reuse/create GIDs 992 and 993 and add the selected user |
| `android` | — | Profile scripts, SDK/AVD startup, Appium, and Supervisor services |

All Features accept `username`, defaulting to the Dev Container remote user (or the existing UID 1000 user). They expect an existing user. SSH and Android service integration targets the desktop-in-docker image, which supplies Supervisor and passwordless sudo for that user. KVM device mapping belongs in Compose, not in the installer. Select the Java and Node.js Features before Android; the generated configuration includes them and sets their installation order.

The build script stages these Features in `build/.devcontainer/features/` and generates `devcontainer.json`. It refreshes the Android profile payload from the pinned submodule, plus project startup and Supervisor files, before building. Feature installation runs during image build; SDK and AVD provisioning runs at container startup into persistent volumes.

For another local Dev Container, copy the selected Feature directories under `.devcontainer/features/` and reference them in `devcontainer.json`:

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

## Reused upstream installers

Git 1.3.8, Node 2.1.1, and Python 1.8.0 installers from [devcontainers/features](https://github.com/devcontainers/features) are bundled, unmodified, under the corresponding `upstream/` directories. Each copy includes its license, metadata, and source revision. The local Feature is the single public entry point and selects its installer internally. There is no generic development-tools Feature.

Compatibility decisions:

- Java retains the existing OpenJDK/Temurin package installation, JDK version option, TUNA Temurin repositories, and Arch architecture selection.
- Node retains NVM 0.40.3, the current Node release, China mirror selection, npm, shell initialization, and the existing NVM location. Official installers are used only on their supported distributions and for the default source.
- Python retains pip and virtual environment support. Its source selection switches between PyPI and the TUNA PyPI mirror for installation and persists the selected index in global pip configuration. The official installer uses OS-provided Python and installs `virtualenv`; it also provides pipx.
- Git remains available in every image.
- npm retains `nrm`, Tencent registry selection, and root/user configuration.
- SSH retains key-only authentication and Supervisor service management, rather than introducing the official SSH Feature's separate entrypoint.
- Android and KVM retain pinned profile provisioning, Appium plugins/driver installation, existing SDK/AVD paths, Supervisor integration, and GIDs 992/993.

For an installer update, compare the upstream options and distribution support, preserve the source/license records, then run configuration tests and actual Feature build checks before accepting it.

## Automatic source selection

Java, Node.js, and Python default to `source: "auto"`. Preset choices are `default` and `china`; mirror selection stays inside each Feature.

Selection priority:

1. An explicit `source` option.
2. A per-tool build environment variable (`JAVA_SOURCE`, `NODEJS_SOURCE`, or `PYTHON_SOURCE`), then `FEATURE_SOURCE`.
3. Legacy `chinaMirror: true`.
4. The `timezone` option, `TZ`, `/etc/timezone`, or `/etc/localtime`.

Mainland China timezone identifiers select China mirrors; other timezones select the default source. `source: "default"` explicitly disables China mirrors. The legacy boolean is retained, but `chinaMirror: false` alone now permits automatic selection.

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
