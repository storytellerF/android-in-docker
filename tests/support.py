"""Shared process and temporary Docker resource management for the tests."""
from contextlib import ExitStack, contextmanager
import os
from pathlib import Path
import shlex
import subprocess
import uuid
import unittest

ROOT = Path(__file__).resolve().parents[1]


def run(args, *, env=None, check=True, capture=True, input=None):
    result = subprocess.run(
        [str(arg) for arg in args], cwd=ROOT, env=env, text=True, input=input,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.STDOUT if capture else None,
    )
    if check and result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}): {shlex.join(map(str, args))}\n{result.stdout or ''}")
    return result


@contextmanager
def built_image(fixture, *, target=None, build_args=None):
    image = f"android-in-docker-test:{uuid.uuid4().hex}"
    args = ["docker", "build", "-f", ROOT / "tests/docker" / fixture, "-t", image]
    if target:
        args += ["--target", target]
    for key, value in (build_args or {}).items():
        args += ["--build-arg", f"{key}={value}"]
    try:
        run([*args, ROOT], capture=False)
        yield image
    finally:
        run(["docker", "image", "rm", image], check=False)


class Container:
    def __init__(self, name):
        self.name = name

    def command(self, *args, user=None, check=True):
        command = ["docker", "exec"]
        if user:
            command += ["--user", user]
        return run([*command, self.name, *args], check=check)

    def output(self, *args, user=None):
        return self.command(*args, user=user).stdout.strip()


@contextmanager
def running_container(image, *, user=None, env=None, offline=False):
    name = f"android-test-{uuid.uuid4().hex}"
    args = ["docker", "run", "--detach", "--name", name]
    if user:
        args += ["--user", user]
    if offline:
        args += ["--network", "none", "--hostname", name, "--add-host", f"{name}:127.0.0.1"]
    for key, value in (env or {}).items():
        args += ["--env", f"{key}={value}"]
    try:
        run([*args, "--entrypoint", "/bin/sh", image, "-c", "exec sleep infinity"])
        yield Container(name)
    finally:
        run(["docker", "rm", "--force", name], check=False)


def clean_source_env(**values):
    env = os.environ.copy()
    for key in ("SOURCE", "FEATURE_SOURCE", "JAVA_SOURCE", "NODEJS_SOURCE", "PYTHON_SOURCE", "TIMEZONE", "TZ"):
        env.pop(key, None)
    env.update(values)
    return env


class DockerImageTests(unittest.TestCase):
    """Build one fixture per class while giving each test its own containers."""
    @classmethod
    def setUpClass(cls):
        stack = ExitStack()
        cls.addClassCleanup(stack.close)
        cls.image = stack.enter_context(built_image(cls.fixture, build_args=cls.build_arguments()))

    @classmethod
    def build_arguments(cls):
        return {}
