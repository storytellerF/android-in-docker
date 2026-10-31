"""Exercise the shell VNC launcher without opening a graphical client."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from support import ROOT
sys.path.insert(0, str(ROOT / "scripts"))
from build_config import write_env


class VncConfigTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="vnc-config-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        compose = self.directory / "docker/compose/docker-compose.yml"
        compose.parent.mkdir(parents=True)
        compose.write_text("services: {}\n")
        self.config = self.directory / ".env"
        self.encoder_input = self.directory / "encoder-input"
        self.viewer_args = self.directory / "viewer-args"
        self.password_file = self.directory / ".tmp/passwd"
        self.bash = shutil.which("bash")
        # Keep host GUI clients out of PATH so this test cannot launch an application.
        for command in ("python3", "dirname", "mkdir", "chmod", "grep", "sed", "head"):
            source = sys.executable if command == "python3" else shutil.which(command)
            if not source:
                self.fail(f"Missing test prerequisite: {command}")
            (self.bin / command).symlink_to(source)
        for command in ("docker", "vncpasswd", "vncviewer"):
            target = self.bin / command
            shutil.copyfile(ROOT / "tests/fixtures/vnc_command.py", target)
            target.chmod(0o755)
        self.env = {**os.environ, "PATH": str(self.bin), "VNC_TEST_ENCODER_INPUT": str(self.encoder_input),
                    "VNC_TEST_VIEWER_ARGS": str(self.viewer_args)}
        self.env.pop("VNC_TEST_ENCODER_IMAGE", None)

    def launch(self, env=None):
        return subprocess.run([self.bash, ROOT / "scripts/open-vnc.sh"], cwd=self.directory, env=env or self.env,
                              text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    def test_literal_password_reaches_encoder_and_viewer(self):
        for password in ("ab$cd123", "secret\\", "a\\'b1234", 'ab"cd123', "-nnnnnnn", "测$试\\"):
            with self.subTest(password=password):
                write_env(self.config, {"VNC_PASSWD": password})
                result = self.launch()
                self.assertEqual(result.returncode, 0, result.stdout)
                expected = (password + "\n").encode()
                self.assertEqual(self.encoder_input.read_bytes(), expected)
                self.assertEqual(self.password_file.read_bytes(), expected)
                self.assertEqual(json.loads(self.viewer_args.read_text()), ["localhost:15901", "-passwd", ".tmp/passwd"])
                self.assertEqual(self.password_file.stat().st_mode & 0o777, 0o600)

    def test_legacy_password_alias_is_decoded(self):
        write_env(self.config, {"VNC_PASSWORD": "ab$cd123"})
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.encoder_input.read_bytes(), b"ab$cd123\n")

    def test_primary_password_takes_precedence_over_alias(self):
        write_env(self.config, {"VNC_PASSWD": "primary$", "VNC_PASSWORD": "alias"})
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.encoder_input.read_bytes(), b"primary$\n")

    def test_missing_password_uses_existing_default(self):
        write_env(self.config, {"UNRELATED": "value"})
        result = self.launch()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.encoder_input.read_bytes(), b"password\n")

    def test_invalid_configuration_stops_before_encoding_or_launching(self):
        self.config.write_text('VNC_PASSWD="unterminated\n')
        result = self.launch()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Cannot read VNC configuration", result.stdout)
        self.assertFalse(self.encoder_input.exists())
        self.assertFalse(self.viewer_args.exists())
        self.assertFalse(self.password_file.exists())

    @unittest.skipUnless(os.environ.get("VNC_TEST_ENCODER_IMAGE"), "Set VNC_TEST_ENCODER_IMAGE for real TigerVNC encoding")
    def test_password_file_matches_real_tigervnc_encoding(self):
        docker = shutil.which("docker")
        image = os.environ["VNC_TEST_ENCODER_IMAGE"]
        env = {**self.env, "VNC_TEST_ENCODER_IMAGE": image, "VNC_TEST_REAL_DOCKER": docker}
        for password in ("ab$cd123", "secret\\", "a\\'b1234", 'ab"cd123', "-nnnnnnn", "测$试\\"):
            with self.subTest(password=password):
                write_env(self.config, {"VNC_PASSWD": password})
                result = self.launch(env)
                self.assertEqual(result.returncode, 0, result.stdout)
                expected = subprocess.run([docker, "run", "--rm", "--pull=never", "--network=none", "-i",
                                           "--entrypoint", "/usr/bin/vncpasswd", image, "-f"],
                                          input=(password + "\n").encode(), stdout=subprocess.PIPE, check=True).stdout
                self.assertEqual(self.password_file.read_bytes(), expected)
                self.assertEqual(self.encoder_input.read_bytes(), (password + "\n").encode())


if __name__ == "__main__":
    unittest.main()
