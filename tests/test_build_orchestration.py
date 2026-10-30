import itertools
import json
import os
from pathlib import Path
import tempfile
import sys
import unittest

from support import ROOT, run
sys.path.insert(0, str(ROOT / "scripts"))
from build_config import read_env, write_env


def build_options(args):
    return dict(args[index + 1].split("=", 1) for index, arg in enumerate(args) if arg == "--build-arg")


class BuildOrchestrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="android-fake-docker-")
        self.addCleanup(self.temp.cleanup)
        self.log = Path(self.temp.name) / "commands.jsonl"
        self.env_log = Path(self.temp.name) / "environment.jsonl"
        self.config_path = Path(self.temp.name) / "config with spaces" / "build.env"
        self.env = os.environ.copy()
        for key in ("DOCKER_USERNAME", "BASE_SYSTEM", "BASE_VERSION", "DESKTOP_TYPE", "OPENJDK_VERSION", "JDK_PROVIDER", "IMAGE_REF"):
            self.env.pop(key, None)
        self.env.update(PATH=str(ROOT / "tests/fake-bin") + os.pathsep + self.env["PATH"], FAKE_DOCKER_LOG=str(self.log), FAKE_DOCKER_ENV_LOG=str(self.env_log), IMAGE_TAG_TIME="20261030182842")

    def build(self, *args, check=True):
        return run([sys.executable, ROOT / "scripts/build-image.py", "--config", self.config_path, *args], env=self.env, check=check)

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_build_matrix_forwards_selected_options(self):
        users = {"debian": "debian", "ubuntu": "ubuntu", "fedora": "user", "alpine": "alpine"}
        for system, provider, mirror in itertools.product(users, ("openjdk", "temurin"), ("--cn-mirror", "--no-cn-mirror")):
            with self.subTest(system=system, provider=provider, mirror=mirror):
                self.build("-b", mirror, "-z", "UTC", "--jdk-provider", provider, "-s", system)
                args = next(args for args in reversed(self.commands()) if args[:2] == ["docker", "build"] and args[args.index("-f") + 1] == "docker/Dockerfile")
                options = build_options(args)
                self.assertEqual(options["USERNAME"], users[system])
                self.assertEqual(options["JDK_PROVIDER"], provider)
                self.assertEqual(options["OPENJDK_VERSION"], "21")
                self.assertEqual(options["TOOL_SOURCE"], "china" if mirror == "--cn-mirror" else "default")
                self.assertGreaterEqual(args.count("-t"), 2)

    def test_publish_builds_dependencies_before_multi_arch_image(self):
        self.build("-P", "--namespace", "example", "--no-cn-mirror", "-z", "UTC")
        built = set()
        published = False
        for args in self.commands():
            self.assertNotEqual(args[0], "devcontainer")
            if args[:2] != ["docker", "build"] and args[:3] != ["docker", "buildx", "build"]:
                continue
            mode = "publish" if "--push" in args else "local"
            options = build_options(args)
            for key in ("BASE_IMAGE", "DESKTOP_BASE_IMAGE"):
                if key in options:
                    self.assertIn((mode, options[key]), built)
            if args[args.index("-f") + 1] == "docker/Dockerfile":
                self.assertEqual(args[:3], ["docker", "buildx", "build"])
                self.assertIn("--push", args)
                self.assertEqual(args[args.index("--platform") + 1], "linux/amd64,linux/arm64")
                published = True
            built.update((mode, args[index + 1]) for index, arg in enumerate(args) if arg == "-t")
        self.assertTrue(published)

    def test_start_uses_kvm_compose_and_reports_endpoints(self):
        result = self.build("-b", "-S", "--no-cn-mirror", "-z", "UTC")
        self.assertIn("ADB: adb connect localhost:15555", result.stdout)
        self.assertIn("Web VNC: http://localhost:16080/vnc.html", result.stdout)
        self.assertTrue(any("docker/compose/docker-compose.kvm.yml" in args and "up" in args for args in self.commands()))

    def test_compose_starts_the_exact_reference_just_built(self):
        for namespace in ("", "example"):
            with self.subTest(namespace=namespace):
                self.build("-b", "-S", "--namespace", namespace, "--no-cn-mirror", "-z", "UTC")
                build = next(args for args in reversed(self.commands()) if args[:2] == ["docker", "build"] and "docker/Dockerfile" in args)
                tags = [build[index + 1] for index, arg in enumerate(build) if arg == "-t"]
                environment = json.loads(self.env_log.read_text().splitlines()[-1])
                self.assertIn(environment["IMAGE_REF"], tags)
                expected = (namespace + "/" if namespace else "") + "android-in-docker:"
                self.assertTrue(environment["IMAGE_REF"].startswith(expected))

    def test_interactive_configuration_is_used_by_a_later_build(self):
        run([sys.executable, ROOT / "scripts/build-image.py", "--config", self.config_path,
             "-c", "--namespace", "example", "-z", "UTC"], env=self.env, input="25\nliteral $password\n\n")
        self.build("-b", "--no-cn-mirror", "-z", "UTC")
        args = next(args for args in reversed(self.commands()) if args[:2] == ["docker", "build"] and "docker/Dockerfile" in args)
        self.assertEqual(build_options(args)["OPENJDK_VERSION"], "25")
        self.assertEqual(read_env(self.config_path)["VNC_PASSWD"], "literal $password")

    def test_invalid_interactive_recipe_preserves_existing_file_and_skips_build(self):
        write_env(self.config_path, {"IMAGE_REF": "example/android:existing", "VNC_PASSWD": "keep-me"})
        original = self.config_path.read_bytes()
        result = run([sys.executable, ROOT / "scripts/build-image.py", "--config", self.config_path,
                      "-c", "-b", "-s", "fedora", "-v", "44", "-j", "25"],
                     env=self.env, input="21\n\n\n", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Fedora 44 no longer ships", result.stdout)
        self.assertEqual(self.config_path.read_bytes(), original)
        self.assertEqual(self.commands(), [])

    def test_invalid_interactive_namespace_is_rejected_before_persistence(self):
        result = run([sys.executable, ROOT / "scripts/build-image.py", "--config", self.config_path, "-c"],
                     env=self.env, input="21\n\nUpperCase\n", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.config_path.exists())
        self.assertEqual(self.commands(), [])

    def test_runtime_commands_ignore_unavailable_build_recipe(self):
        for operation in ("-S", "-T"):
            with self.subTest(operation=operation):
                write_env(self.config_path, {"IMAGE_REF": "example/android:existing", "CONTAINER_HOME": "/home/user",
                                            "BASE_SYSTEM": "fedora", "BASE_VERSION": "44", "OPENJDK_VERSION": "21"})
                self.build(operation)
                environment = json.loads(self.env_log.read_text().splitlines()[-1])
                self.assertEqual(environment["IMAGE_REF"], "example/android:existing")
                self.assertTrue(all(command[:2] == ["docker", "compose"] for command in self.commands()))

    def test_multi_arch_without_publish_is_rejected_before_docker(self):
        result = self.build("-b", "-m", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.commands(), [])

    def test_desktop_dependency_treats_timezone_as_literal_data(self):
        marker = Path(self.temp.name) / "unexpected"
        self.build("-b", "--no-cn-mirror", "-z", f"UTC'; touch {marker}; #")
        self.assertFalse(marker.exists())

    def test_stop_uses_kvm_compose(self):
        self.build("-T", "--no-cn-mirror", "-z", "UTC")
        self.assertTrue(any("docker/compose/docker-compose.kvm.yml" in args and "down" in args for args in self.commands()))

    def test_removed_options_and_unsupported_desktops_fail(self):
        for args in (("--dev",), ("--system-image", "unused"), ("-b", "-s", "arch", "--no-cn-mirror"), ("-b", "-s", "ubuntu", "-v", "resolute", "--no-cn-mirror")):
            with self.subTest(args=args):
                result = self.build(*args, check=False)
                self.assertNotEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
