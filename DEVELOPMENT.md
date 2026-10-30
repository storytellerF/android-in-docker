# Development

## Build architecture

`scripts/build-image.py` builds the pinned desktop dependency, then builds `docker/Dockerfile` with Docker. It forwards the selected desktop image, username, Java provider/version, and mirror source as build arguments. Publishing uses Buildx with `--push` for both supported architectures. The entry point requires Python 3.10+ and Bash; no Dev Container CLI or host Node.js installation is needed for image builds.

The Dockerfile runs the shared `features/*/install.sh` scripts as root in dependency order, passing `_REMOTE_USER` for user-specific setup. Java, Node, Python, and SDK runtime paths are declared with `ENV`; Feature metadata is only consumed by external Dev Container users. When changing runtime paths, update both the Dockerfile and the corresponding Feature metadata.

Node installation shares one NVM implementation across Debian/Ubuntu, Fedora, and Arch, with source selection applied before installation. Alpine uses distribution Node.js packages. Python uses distribution packages on every supported system and exposes stable Python/pip aliases under `/usr/local/python/current/bin`. The selected user owns `/usr/local/py-utils` so pipx applications can be installed without root. No `devcontainers/features` installer copies are bundled.

The Python entry point resolves CLI, environment, and literal `.env` values into an immutable `BuildConfig` (`scripts/build_config.py`). CLI values take precedence, followed by process environment and saved values. It does not execute `.env` as shell code. The dotenv writer uses double-quoted values with escaped backslashes, quotes, and dollar signs; Python and real Compose round-trip tests cover the same literals. Build execution, desktop dependency staging, and Compose operations consume this same configuration. A successful build atomically records `IMAGE_REF` and its configuration; startup validates Compose interpolation against that reference before creating containers. `--config` selects another configuration file, and `--project-name` isolates a Compose stack.

Recipe resolution, final build validation, and runtime target selection are separate phases. CLI and interactive recipes share `validate_build_config`, called after prompts and before saving or invoking Docker. A rejected edit leaves the previous file intact. Runtime-only commands use the recorded `IMAGE_REF`, `CONTAINER_HOME`, and `CONTAINER_USER` through `RuntimeConfig`, without applying current installation availability rules. Explicit image-selection flags resolve another reference from recipe fields; legacy files without `IMAGE_REF` can still resolve their recorded tag. Runtime timezone/password overrides keep the recorded image.

The distribution-specific Java adapters own package names, package queries, and the selected JDK path. They record the canonical home through `JDK_HOME_FILE`; the shared entry point only validates and activates it. RPM adapters query `--noghost`, and `record-home.sh` excludes global alternatives links.

`features/_common/source-selection.sh` is the sole maintained source-selection implementation. Repository builds read it directly; Feature release staging copies it into each independently installable Feature. SSH startup and Supervisor configuration live only in `features/ssh/`.

## Validation

Test runners use Python's standard-library `unittest` module. Bash is required to exercise the production shell scripts:

```sh
python3 tests/test_build_config.py
python3 tests/test_build_orchestration.py
python3 tests/test_feature_packaging.py
python3 tests/test_java_home.py
python3 tests/test_compose_config.py
python3 tests/test_android_startup.py
python3 tests/test_feature_sources.py
```

The fake Docker checks cover supported build combinations, image dependency order, publishing arguments, and Compose commands. They do not build images.

Real installation tests use Docker directly and download tool packages:

```sh
python3 tests/smoke_features.py
NODEJS_CHINA_MIRROR=true PYTHON_CHINA_MIRROR=true python3 tests/smoke_features.py
```

The smoke test checks Git, JDK 21, Node/npm/NVM, Python/pip/virtualenv, offline pipx application installation, virtual environment creation, and KVM group reuse as a non-root user. It does not boot an Android emulator or validate the full desktop image.

## Node.js Corepack regression test

With Docker and Python 3 installed, run:

```sh
python3 tests/test_nodejs_system_corepack.py
```

The test installs distribution-provided Corepack in Debian before calling the Node.js installer for a non-root user. It verifies that the installer supplies the runtime libraries needed by Node and that the system Corepack creates executable Yarn and pnpm shims beside the NVM Node executable without requiring write access to `/usr/bin`. The test downloads Node.js and removes its temporary image after completion.

Node installation is maintained in `features/nodejs/install-nvm.sh`. It installs NVM and Node as the selected user, includes the platform runtime libraries, and enables an existing Corepack beside the selected Node executable. Run the regression test and `python3 tests/smoke_features.py` after changes.

## Installer selection regression tests

```sh
python3 tests/test_java_selection.py
python3 tests/test_java_selection_fedora.py
python3 tests/test_npm_registry.py
```

The Fedora test keeps global alternatives on JDK 25 while selecting package-owned JDK 21. Fedora 43 is the default Fedora base because Fedora 44 [removed system OpenJDK 21](https://fedoraproject.org/wiki/Changes/Java21RemovedEarlierThenScheduled); select Temurin 21 or OpenJDK 25 for Fedora 44.

The Debian Java test installs OpenJDK, selects Temurin while the existing JDK remains on `PATH`, and then selects OpenJDK again. Each resulting image must run the requested vendor's Java and javac through `JAVA_HOME`.

The npm test builds an image with npm and sudo, then disables container networking before running registry configuration for root and a non-root user. Both global and user configuration must contain the explicit registry. Registry configuration must not download `nrm` or switch to a preset registry; `nrm` installation belongs only to the China preset without an explicit override.

Each regression is reported independently. Docker image and container cleanup runs even when a test fails. `tests/fake-bin/docker` is a Python command recorder; its JSON-lines log preserves argument boundaries, including paths containing spaces. `tests/fixtures/android_step.py` simulates the SDK/AVD commands without starting a device.

## Feature publication

Feature packaging and GHCR publication remain separate from image builds. The publishing workflow installs Dev Container CLI 0.87.0 and uses `scripts/prepare-feature-release.py` to stage metadata for its destination namespace. This release workflow additionally requires Node.js. Normal image builds and installation tests use Python 3 and Docker, without the Dev Container CLI.

## Production image and Compose integration

Build the pinned desktop image first, or reuse a local image built from that revision. Then run:

```sh
ANDROID_TEST_DESKTOP_IMAGE=desktop-in-docker:<pinned-build-tag> python3 tests/test_image_composition.py
```

The test calls the real Python build entry point with `--desktop-image`, builds the production `docker/Dockerfile`, renders the actual Compose configuration for local and namespaced image references, and checks runtime environment values against Feature metadata. It starts an isolated Compose project and verifies the installed tools, noVNC page, SSH key authentication, and Appium readiness. The test requires Docker Compose 2.24+, KVM mapping, SSH client tools, internet access, and initialized submodules.

Only the Android Supervisor program is disabled in this service integration test; SDK/AVD downloads and emulator boot are covered separately by the pinned Android project and startup sequencing tests. The test removes its own containers, volumes, image tags, keys, and temporary configuration. Production Compose does not include this override. It does not run global image pruning.

The shared runtime paths are also declared in Feature metadata for external consumers. Production integration checks their agreement instead of treating the separate tool smoke fixture as full-image coverage. Distribution smoke tests remain useful for installer regressions and do not replace this integration check.

For the real Python CLI start/stop regression, use a disposable checkout without `logs` or `data/authorized_keys`:

```sh
ANDROID_TEST_RUNTIME_IMAGE=android-in-docker:<verified-debian-tag> python3 tests/test_runtime_commands.py
```

This check records an existing image alongside retired Fedora 44/OpenJDK 21 recipe metadata, then starts and stops it through the real Python entry point. It preserves the image's recorded user/home, checks the exact selected image and literal password, disables only Android startup in a test image, and cleans its isolated Compose project, temporary bind sources, and image tag. It refuses to replace existing log or key paths.

## VNC client configuration regression

`scripts/open-vnc.sh` calls `scripts/read-vnc-password.py`, which uses the shared `read_env` decoder. It preserves literal dollar signs, backslashes, and quotes, supports the legacy `VNC_PASSWORD` alias, and stops before launching a client when configuration parsing fails. Password input is passed to the encoder with `printf`.

```sh
python3 tests/test_vnc_config.py
VNC_TEST_ENCODER_IMAGE=android-in-docker:<verified-debian-tag> python3 tests/test_vnc_config.py
```

The launcher test uses isolated command adapters, records the encoder's exact input, and checks the viewer arguments and password-file permissions without opening a GUI. With the image option, the real TigerVNC encoder runs in disposable offline containers and its output is compared with direct encoding of the original password. Bash and standard Unix tools are required.
