"""Build the production Dockerfile and exercise its actual Compose/service contracts."""
from contextlib import ExitStack
from datetime import datetime
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from urllib.request import urlopen
import uuid

from support import ROOT, run
sys.path.insert(0, str(ROOT / "scripts"))
from build_config import argument_parser, resolve_config, write_env


def wait_http(url, timeout=90):
    deadline = time.monotonic() + timeout
    while True:
        try:
            with urlopen(url, timeout=3) as response:
                return response.read()
        except OSError:
            if time.monotonic() >= deadline:
                raise
            time.sleep(0.5)


class ImageCompositionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        desktop = os.environ.get("ANDROID_TEST_DESKTOP_IMAGE")
        if not desktop:
            raise RuntimeError("Set ANDROID_TEST_DESKTOP_IMAGE to a built pinned desktop image")
        stack = ExitStack()
        cls.addClassCleanup(stack.close)
        cls.temporary = Path(stack.enter_context(tempfile.TemporaryDirectory(prefix="android-composition-")))
        cls.project = "android-validation-" + uuid.uuid4().hex[:10]
        cls.config_path = cls.temporary / ".env"
        args = argument_parser().parse_args(["--namespace", cls.project, "--no-snapshot", "--no-cn-mirror", "-z", "UTC", "-p", "secret\\"])
        cls.config = resolve_config(args, {}, {"IMAGE_TAG_TIME": datetime.now().strftime("%Y%m%d%H%M%S")})
        cls.literals = {
            "LITERAL_TEXT": "spaces $literal 'quote' \\path", "LITERAL_TRAILING_SLASH": "end\\",
            "LITERAL_SLASH_QUOTE": "a\\'b", "LITERAL_QUOTES": 'a"b', "LITERAL_DOLLARS": "$$ ${literal} $literal",
            "LITERAL_UNICODE": "测试路径\\",
        }
        write_env(cls.config_path, {**cls.config.persisted(), **cls.literals})
        stack.callback(run, ["docker", "image", "rm", *cls.config.tags()], check=False)
        run([sys.executable, ROOT / "scripts/build-image.py", "--config", cls.config_path,
             "--desktop-image", desktop, "--no-snapshot", "-b"],
            env={key: value for key, value in os.environ.items() if key not in cls.config.persisted()}, capture=False)
        cls.env = {**os.environ, **cls.config.persisted(), "ANDROID_ENV_FILE": str(cls.config_path), "TEST_RUNTIME_DIR": str(cls.temporary)}
        (cls.temporary / "logs").mkdir(mode=0o777)
        (cls.temporary / "logs").chmod(0o777)
        cls.key = cls.temporary / "identity"
        run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", cls.key])
        (cls.temporary / "authorized_keys").write_text(cls.key.with_suffix(".pub").read_text())
        cls.compose = ["docker", "compose", "-f", "docker/compose/docker-compose.yml", "-f", "docker/compose/docker-compose.kvm.yml",
                       "-f", "tests/compose/runtime-smoke.yml", "--project-name", cls.project]
        stack.callback(run, [*cls.compose, "down", "--volumes"], env=cls.env, check=False)
        run([*cls.compose, "up", "-d", "--no-build", "--pull", "never"], env=cls.env)
        cls.container = run([*cls.compose, "ps", "-q", "android"], env=cls.env).stdout.strip()
        run(["docker", "exec", "-d", cls.container, "bash", "-lc", "exec appium --address 0.0.0.0 --port 4723" ])

    @classmethod
    def port(cls, number):
        address = run([*cls.compose, "port", "android", str(number)], env=cls.env).stdout.strip().splitlines()[0]
        return address.rsplit(":", 1)[1]

    def test_compose_image_and_home_match_build_config_for_both_namespaces(self):
        for namespace in ("", "example"):
            with self.subTest(namespace=namespace):
                args = argument_parser().parse_args(["--namespace", namespace])
                config = resolve_config(args, self.config.persisted(), {})
                env = {**self.env, **config.persisted()}
                resolved = json.loads(run([*self.compose, "config", "--format", "json"], env=env).stdout)
                service = resolved["services"]["android"]
                self.assertEqual(service["image"], config.image_ref)
                targets = [volume["target"] for volume in service["volumes"]]
                self.assertIn(f"{config.home}/Android/Sdk", targets)
                self.assertIn(f"{config.home}/.android/avd", targets)

    def test_saved_literal_configuration_reaches_container(self):
        for key, expected in {**self.literals, "VNC_PASSWD": self.config.password}.items():
            with self.subTest(key=key):
                value = run(["docker", "exec", self.container, "printenv", key]).stdout.rstrip("\n")
                self.assertEqual(value, expected)

    def test_production_runtime_environment_matches_feature_metadata(self):
        image = json.loads(run(["docker", "image", "inspect", self.config.image_ref]).stdout)[0]
        environment = dict(item.split("=", 1) for item in image["Config"]["Env"])
        for feature in ("java", "nodejs", "python"):
            metadata = json.loads((ROOT / f"features/{feature}/devcontainer-feature.json").read_text())
            for key, expected in metadata["containerEnv"].items():
                with self.subTest(feature=feature, key=key):
                    if key == "PATH":
                        for segment in expected.split(":"):
                            if segment != "${PATH}":
                                self.assertIn(segment, environment["PATH"].split(":"))
                    else:
                        self.assertEqual(environment[key], expected)
        self.assertEqual(image["Config"]["User"], self.config.user)

    def test_production_image_runs_all_installed_tools_as_selected_user(self):
        for command in (("java", "-version"), ("node", "--version"), ("npm", "--version"),
                        ("python", "--version"), ("pip", "--version"), ("pipx", "--version"), ("appium", "--version")):
            with self.subTest(command=command):
                run(["docker", "exec", "--user", self.config.user, self.container, *command])
        for script in ("install-sdk.sh", "create-avd.sh", "start-avd.sh", "start-android.sh", "start-ssh.sh"):
            with self.subTest(script=script):
                run(["docker", "exec", self.container, "test", "-x", f"{self.config.home}/bin/{script}"])

    def test_desktop_serves_novnc_page(self):
        page = wait_http(f"http://127.0.0.1:{self.port(6080)}/vnc.html")
        self.assertIn(b"noVNC", page)

    def test_appium_status_is_ready(self):
        status = json.loads(wait_http(f"http://127.0.0.1:{self.port(4723)}/status"))
        self.assertTrue(status["value"]["ready"])

    def test_ssh_authenticates_with_authorized_key(self):
        command = ["ssh", "-i", self.key, "-p", self.port(22), "-o", "BatchMode=yes", "-o", "ConnectTimeout=3",
                   "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "IdentitiesOnly=yes",
                   f"{self.config.user}@127.0.0.1", "id -un"]
        deadline = time.monotonic() + 45
        while True:
            result = run(command, check=False)
            if result.returncode == 0 or time.monotonic() >= deadline:
                self.assertEqual(result.returncode, 0, result.stdout)
                self.assertEqual(result.stdout.strip().splitlines()[-1], self.config.user)
                break
            time.sleep(0.5)


if __name__ == "__main__":
    unittest.main()
