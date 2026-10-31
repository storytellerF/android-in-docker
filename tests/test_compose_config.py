"""Validate the actual Compose interpolation without starting containers."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

from support import ROOT, run
sys.path.insert(0, str(ROOT / "scripts"))
from build_config import SYSTEMS, argument_parser, resolve_config, write_env


class ComposeConfigTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="android-compose-config-")
        self.addCleanup(temporary.cleanup)
        self.path = Path(temporary.name) / ".env"
        self.compose = ["docker", "compose", "--env-file", self.path, "-f", "docker/compose/docker-compose.yml", "-f", "docker/compose/docker-compose.kvm.yml"]

    def test_image_and_home_agree_for_all_systems_and_namespaces(self):
        for system in SYSTEMS:
            for namespace in ("", "example"):
                with self.subTest(system=system, namespace=namespace):
                    config = resolve_config(argument_parser().parse_args(["-s", system, "--namespace", namespace]), {}, {})
                    write_env(self.path, config.persisted())
                    env = {**os.environ, **config.persisted(), "ANDROID_ENV_FILE": str(self.path)}
                    service = json.loads(run([*self.compose, "config", "--format", "json"], env=env).stdout)["services"]["android"]
                    self.assertEqual(service["image"], config.image_ref)
                    targets = [volume["target"] for volume in service["volumes"]]
                    self.assertIn(f"{config.home}/Android/Sdk", targets)
                    self.assertIn(f"{config.home}/.ssh/authorized_keys", targets)

    def test_dotenv_special_characters_are_accepted_by_real_compose(self):
        for literal in ("end\\", "a\\'b", "\\'", 'a"b', "two\\\\end", "测试路径\\"):
            with self.subTest(literal=literal):
                config = resolve_config(argument_parser().parse_args([]), {}, {})
                write_env(self.path, {**config.persisted(), "VNC_PASSWD": literal, "CUSTOM_LITERAL": literal})
                env = dict(os.environ)
                for key in config.persisted():
                    env.pop(key, None)
                env["ANDROID_ENV_FILE"] = str(self.path)
                service = json.loads(run([*self.compose, "config", "--format", "json"], env=env).stdout)["services"]["android"]
                self.assertEqual(service["environment"]["VNC_PASSWD"], literal)
                self.assertEqual(service["environment"]["CUSTOM_LITERAL"], literal)

    def test_compose_rejects_missing_full_image_reference(self):
        self.path.write_text("")
        env = dict(os.environ)
        env.pop("IMAGE_REF", None)
        result = run([*self.compose, "config", "--images"], env=env, check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("IMAGE_REF", result.stdout)


if __name__ == "__main__":
    unittest.main()
