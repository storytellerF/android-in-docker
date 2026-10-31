#!/usr/bin/env python3
"""Execute image builds and Compose operations using one resolved configuration."""
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys
import tempfile

from build_config import ROOT, SYSTEMS, DESKTOPS, argument_parser, read_env, write_env, resolve_config, prompt_config, validate_build_config, RuntimeConfig, resolve_runtime_config


def run(args, *, cwd=ROOT, env=None, capture=False):
    return subprocess.run([str(arg) for arg in args], cwd=cwd, env=env, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None)


def build_desktop(config, publish):
    source = ROOT / "external/desktop-in-docker"
    if not (source / "scripts/build-image.sh").is_file():
        raise ValueError("Initialize the desktop submodule: git submodule update --init --recursive")
    # The child owns its recipe; temporary configuration cannot dirty its checkout.
    with tempfile.TemporaryDirectory(prefix="android-desktop-build-") as temporary:
        context = Path(temporary) / "desktop"
        shutil.copytree(source, context, symlinks=True, ignore=shutil.ignore_patterns(".git", ".env*", "build"))
        # The pinned child reads Bash assignments, while our own configuration is dotenv.
        values = {"DOCKER_USERNAME": config.namespace, "CURRENT_DATE": config.timestamp, "TZ": config.timezone}
        child_env = context / ".env"
        child_env.write_text("".join(f"{key}={shlex.quote(value)}\n" for key, value in values.items()), encoding="utf-8")
        child_env.chmod(0o600)
        args = ["bash", "scripts/build-image.sh", "-s", config.system, "-v", config.version,
                "-d", config.desktop, "--image-variant", "x11", "--cn-mirror" if config.china else "--no-cn-mirror"]
        if config.latest:
            args += ["--latest"]
        if not config.snapshot:
            args += ["--no-snapshot"]
        args += ["-P", "-m"] if publish else ["-b"]
        run(args, cwd=context)


def build_image(config, args):
    if not (ROOT / "external/android-profile/scripts/install-sdk.sh").is_file():
        raise ValueError("Initialize the Android submodule: git submodule update --init --recursive")
    if args.desktop_image:
        if args.publish:
            raise ValueError("--desktop-image is for local builds; publishing builds the pinned dependency")
        desktop_image = args.desktop_image
    else:
        build_desktop(config, args.publish)
        desktop_image = config.desktop_image
    command = ["docker", "buildx", "build", "--platform", "linux/amd64,linux/arm64", "--push"] if args.publish else ["docker", "build"]
    values = dict(DESKTOP_BASE_IMAGE=desktop_image, USERNAME=config.user, JDK_PROVIDER=config.provider,
                  OPENJDK_VERSION=config.jdk, TOOL_SOURCE="china" if config.china else "default")
    for key, value in values.items():
        command += ["--build-arg", f"{key}={value}"]
    for tag in config.tags():
        command += ["-t", tag]
    run([*command, "-f", "docker/Dockerfile", "."])
    print("Built image references:", *config.tags(), sep="\n  ")


def compose_command(project_name=None):
    args = ["docker", "compose", "-f", "docker/compose/docker-compose.yml", "-f", "docker/compose/docker-compose.kvm.yml"]
    if project_name:
        args += ["--project-name", project_name]
    return args


def compose_environment(config, path):
    return {**os.environ, **config.persisted(), "ANDROID_ENV_FILE": str(path.resolve())}


def start_stack(config, args, env):
    command = compose_command(args.project_name)
    # Validate the real Compose interpolation before changing any running containers.
    actual = run([*command, "config", "--images"], env=env, capture=True).stdout.splitlines()
    if actual != [config.image_ref]:
        raise ValueError(f"Compose image differs from resolved image: {actual!r}")
    run([*command, "up", "-d", "--no-build"], env=env)
    for port, label in ((6080, "Web VNC"), (5901, "VNC direct"), (4723, "Appium"), (22, "SSH"), (5555, "ADB")):
        address = run([*command, "port", "android", str(port)], env=env, capture=True).stdout.strip().splitlines()[0]
        host_port = address.rsplit(":", 1)[1]
        endpoints = {6080: f"http://localhost:{host_port}/vnc.html", 5901: f"localhost:{host_port}",
                     4723: f"http://localhost:{host_port}/inspector", 22: f"ssh -p {host_port} {config.user}@localhost",
                     5555: f"adb connect localhost:{host_port}"}
        print(f"{label}: {endpoints[port]}")


def complete(args, parser):
    values = {
        "system": tuple(SYSTEMS), "version": SYSTEMS[args.system][2] if args.system else tuple(dict.fromkeys(v for row in SYSTEMS.values() for v in row[2])),
        "desktop": DESKTOPS, "jdk-provider": ("openjdk", "temurin"), "jdk-version": ("8", "11", "17", "21", "25"),
        "options": tuple(option for action in parser._actions for option in action.option_strings if option != "--completion"),
    }
    print(" ".join(values[args.completion]))


def main():
    parser = argument_parser()
    args = parser.parse_args()
    if args.completion:
        complete(args, parser)
        return
    path = args.config.resolve()
    saved = read_env(path)
    if args.multi_arch and not args.publish:
        raise ValueError("--multi-arch requires --publish; local builds load the host architecture")
    if args.create_env or args.build or args.publish:
        config = resolve_config(args, saved)
        if args.create_env:
            config = prompt_config(config)
        # CLI and interactive values go through the same validation before any writes/builds.
        validate_build_config(config, publish=args.publish)
        if args.create_env:
            write_env(path, {**saved, **config.persisted()})
            print(f"Saved configuration to {path}")
        if args.build or args.publish:
            build_image(config, args)
            write_env(path, {**saved, **config.persisted()})
        runtime = RuntimeConfig.from_build(config)
    else:
        runtime = resolve_runtime_config(args, saved)
    env = compose_environment(runtime, path)
    if args.stop:
        run([*compose_command(args.project_name), "down"], env=env)
    if args.start:
        start_stack(runtime, args, env)
    if not any((args.build, args.publish, args.start, args.stop, args.create_env)):
        print(runtime.image_ref)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Build failed: {error}", file=sys.stderr)
        sys.exit(error.returncode if isinstance(error, subprocess.CalledProcessError) else 1)
