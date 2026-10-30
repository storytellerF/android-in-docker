"""Exercise the real CLI lifecycle in a disposable checkout with a recorded image."""
from contextlib import ExitStack
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
import uuid

from support import ROOT, DockerImageTests, run
sys.path.insert(0, str(ROOT / "scripts"))
from build_config import write_env


class RuntimeCommandTests(DockerImageTests):
    fixture = "runtime-control.Dockerfile"

    @classmethod
    def build_arguments(cls):
        image = os.environ.get("ANDROID_TEST_RUNTIME_IMAGE")
        if not image:
            raise RuntimeError("Set ANDROID_TEST_RUNTIME_IMAGE to a production Debian image")
        return {"RUNTIME_IMAGE": image}

    def test_cli_manages_recorded_image_with_retired_build_recipe(self):
        logs = ROOT / "logs"
        data = ROOT / "data"
        keys = data / "authorized_keys"
        if logs.exists() or logs.is_symlink() or keys.exists() or keys.is_symlink():
            self.fail("Use a disposable checkout without logs or data/authorized_keys")
        with ExitStack() as stack:
            temporary = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="android-cli-runtime-")))
            (temporary / "logs").mkdir(mode=0o777)
            (temporary / "logs").chmod(0o777)
            (temporary / "authorized_keys").write_text("")
            if not data.exists():
                data.mkdir()
                stack.callback(data.rmdir)
            logs.symlink_to(temporary / "logs", target_is_directory=True)
            stack.callback(logs.unlink)
            keys.symlink_to(temporary / "authorized_keys")
            stack.callback(keys.unlink)
            project = "android-runtime-" + uuid.uuid4().hex[:10]
            path = temporary / ".env"
            saved = dict(IMAGE_REF=self.image, CONTAINER_HOME="/home/debian", CONTAINER_USER="debian",
                         BASE_SYSTEM="fedora", BASE_VERSION="44", JDK_PROVIDER="openjdk", OPENJDK_VERSION="21",
                         VNC_PASSWD="secret\\", TZ="UTC")
            write_env(path, saved)
            env = {key: value for key, value in os.environ.items() if key not in saved}
            cleanup_env = {**env, **saved, "ANDROID_ENV_FILE": str(path)}
            compose = ["docker", "compose", "-f", "docker/compose/docker-compose.yml", "-f", "docker/compose/docker-compose.kvm.yml", "--project-name", project]
            stack.callback(run, [*compose, "down", "--volumes"], env=cleanup_env, check=False)
            command = [sys.executable, ROOT / "scripts/build-image.py", "--config", path, "--project-name", project]
            started = run([*command, "-S"], env=env)
            self.assertIn("Web VNC:", started.stdout)
            container = run(["docker", "ps", "-q", "--filter", f"label=com.docker.compose.project={project}"]).stdout.strip()
            self.assertTrue(container)
            details = json.loads(run(["docker", "inspect", container]).stdout)[0]
            self.assertEqual(details["Config"]["Image"], self.image)
            self.assertTrue(details["State"]["Running"])
            self.assertEqual(run(["docker", "exec", container, "printenv", "VNC_PASSWD"]).stdout.rstrip("\n"), saved["VNC_PASSWD"])
            run([*command, "-T"], env=env)
            remaining = run(["docker", "ps", "-aq", "--filter", f"label=com.docker.compose.project={project}"]).stdout.strip()
            self.assertEqual(remaining, "")


if __name__ == "__main__":
    unittest.main()
