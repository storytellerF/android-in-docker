import os
import unittest

from support import DockerImageTests, running_container


class SmokeToolTests(DockerImageTests):
    fixture = "smoke-tools.Dockerfile"

    @classmethod
    def build_arguments(cls):
        cls.python_source = "china" if os.environ.get("PYTHON_CHINA_MIRROR") == "true" else "default"
        return {
            "PYTHON_SOURCE": cls.python_source,
            "NODE_SOURCE": "china" if os.environ.get("NODEJS_CHINA_MIRROR") == "true" else "default",
        }

    def test_git_available(self):
        with running_container(self.image, user="debian") as container:
            self.assertIn("git version", container.output("git", "--version"))

    def test_jdk_21_available(self):
        with running_container(self.image, user="debian") as container:
            self.assertIn("openjdk version", container.output("java", "-version"))
            self.assertRegex(container.output("javac", "-version"), r"\bjavac 21(?:\.|$)")
            home = container.output("printenv", "JAVA_HOME")
            self.assertEqual(container.command("test", "-x", f"{home}/bin/java", check=False).returncode, 0)

    def test_node_npm_and_nvm_available(self):
        with running_container(self.image, user="debian") as container:
            self.assertRegex(container.output("node", "--version"), r"^v\d+\.")
            self.assertRegex(container.output("npm", "--version"), r"^\d+\.")
            self.assertEqual(container.output("bash", "-c", '. /usr/local/nvm/nvm.sh; nvm --version'), "0.40.3")

    def test_nonroot_user_can_install_global_npm_application(self):
        with running_container(self.image, user="debian", offline=True) as container:
            container.command("node", "-e", """
const fs = require('fs');
fs.mkdirSync('/tmp/npm-probe');
fs.writeFileSync('/tmp/npm-probe/package.json', JSON.stringify({name: 'local-npm-probe', version: '1.0.0', bin: {'local-npm-probe': 'probe.js'}}));
fs.writeFileSync('/tmp/npm-probe/probe.js', '#!/usr/bin/env node\\nconsole.log("npm works");\\n');
""")
            container.command("npm", "install", "--global", "--offline", "--no-audit", "--no-fund", "/tmp/npm-probe")
            self.assertEqual(container.output("local-npm-probe"), "npm works")

    def test_python_package_tools_available(self):
        with running_container(self.image, user="debian") as container:
            self.assertIn("Python 3.", container.output("python3", "--version"))
            self.assertIn("pip ", container.output("pip3", "--version"))
            self.assertIn("virtualenv ", container.output("virtualenv", "--version"))

    def test_pipx_can_install_a_local_application_as_nonroot(self):
        with running_container(self.image, user="debian", offline=True) as container:
            # Seed shared pip without a network download; the application is a local wheel.
            container.command("python3", "-m", "venv", "/usr/local/py-utils/shared")
            container.command("python3", "-c", """
from zipfile import ZipFile
metadata = 'local_probe-1.0.dist-info'
with ZipFile('/tmp/local_probe-1.0-py3-none-any.whl', 'w') as wheel:
    wheel.writestr('probe.py', 'def main(): print("pipx works")\\n')
    wheel.writestr(f'{metadata}/METADATA', 'Metadata-Version: 2.1\\nName: local-probe\\nVersion: 1.0\\n')
    wheel.writestr(f'{metadata}/WHEEL', 'Wheel-Version: 1.0\\nRoot-Is-Purelib: true\\nTag: py3-none-any\\n')
    wheel.writestr(f'{metadata}/entry_points.txt', '[console_scripts]\\nlocal-probe = probe:main\\n')
    wheel.writestr(f'{metadata}/RECORD', '')
""")
            container.command(
                "env", "PIP_NO_INDEX=1", "pipx", "install", "--python", "/usr/bin/python3",
                "--pip-args=--no-index", "/tmp/local_probe-1.0-py3-none-any.whl",
            )
            self.assertEqual(container.output("/usr/local/py-utils/bin/local-probe"), "pipx works")

    def test_virtual_environment_contains_pip(self):
        with running_container(self.image, user="debian") as container:
            path = container.output("mktemp", "-d")
            container.command("python3", "-m", "venv", path)
            self.assertIn("pip ", container.output(f"{path}/bin/python", "-m", "pip", "--version"))

    def test_selected_pip_index_persisted(self):
        expected = "https://pypi.tuna.tsinghua.edu.cn/simple" if self.python_source == "china" else "https://pypi.org/simple"
        with running_container(self.image, user="debian") as container:
            self.assertEqual(container.output("pip3", "config", "--global", "get", "global.index-url"), expected)

    def test_kvm_groups_reused_and_assigned_to_user(self):
        with running_container(self.image, user="debian") as container:
            self.assertEqual(container.output("getent", "group", "992").split(":")[0], "existingkvm")
            self.assertTrue({"992", "993"}.issubset(set(container.output("id", "-G").split())))


if __name__ == "__main__":
    unittest.main()
