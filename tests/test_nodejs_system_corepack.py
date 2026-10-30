from pathlib import PurePosixPath
import unittest

from support import DockerImageTests, running_container


class SystemCorepackTests(DockerImageTests):
    fixture = "system-corepack.Dockerfile"

    def test_system_corepack_creates_shims_in_nonroot_nvm_directory(self):
        with running_container(self.image, user="debian") as container:
            self.assertNotEqual(container.command("test", "-w", "/usr/bin", check=False).returncode, 0)
            self.assertEqual(container.output("bash", "-c", "command -v corepack"), "/usr/bin/corepack")
            node = container.output("bash", "-c", "command -v node")
            for manager in ("yarn", "pnpm"):
                with self.subTest(manager=manager):
                    shim = container.output("bash", "-c", f"command -v {manager}")
                    self.assertEqual(PurePosixPath(shim).parent, PurePosixPath(node).parent)
                    self.assertEqual(container.command("test", "-x", shim, check=False).returncode, 0)
                    self.assertEqual(container.output("readlink", "-f", shim), f"/usr/share/nodejs/corepack/dist/{manager}.js")
            self.assertRegex(container.output("node", "--version"), r"^v\d+\.")
            self.assertRegex(container.output("npm", "--version"), r"^\d+\.")
            self.assertRegex(container.output("corepack", "--version"), r"^\d+\.")


if __name__ == "__main__":
    unittest.main()
