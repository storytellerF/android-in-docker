import unittest

from support import DockerImageTests, running_container


class NpmRegistryTests(DockerImageTests):
    fixture = "npm-registry.Dockerfile"

    def verify_registry(self, user):
        registry = "https://registry.example.invalid"
        with running_container(self.image, offline=True, env={"_REMOTE_USER": user, "NPM_REGISTRY": registry}) as container:
            container.command("bash", "/tmp/configure-npm.sh")
            self.assertEqual(container.output("npm", "config", "get", "registry", "--global"), registry)
            if user == "root":
                selected = container.output("npm", "config", "get", "registry")
            else:
                selected = container.output("sudo", "-u", user, "-H", "npm", "config", "get", "registry")
            self.assertEqual(selected, registry)

    def test_root_registry_can_be_configured_offline(self):
        self.verify_registry("root")

    def test_nonroot_registry_can_be_configured_offline(self):
        self.verify_registry("node")


if __name__ == "__main__":
    unittest.main()
