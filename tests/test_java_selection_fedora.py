import unittest

from support import DockerImageTests, running_container


class FedoraJavaSelectionTests(DockerImageTests):
    fixture = "java-selection-fedora.Dockerfile"

    def test_requested_jdk_ignores_higher_priority_global_alternatives(self):
        with running_container(self.image) as container:
            self.assertRegex(container.output("/usr/bin/javac", "-version"), r"\bjavac 25(?:\.|$)")
            self.assertRegex(container.output("javac", "-version"), r"\bjavac 21(?:\.|$)")
            self.assertRegex(container.output("java", "-version"), r'openjdk version "21\.')
            actual = container.output("readlink", "-f", "/usr/local/java/current")
            self.assertTrue(actual.startswith("/usr/lib/jvm/"), actual)


if __name__ == "__main__":
    unittest.main()
