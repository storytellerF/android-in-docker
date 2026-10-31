import re
import unittest

from support import built_image, running_container


class JavaSelectionTests(unittest.TestCase):
    def verify_provider(self, target, vendor):
        with built_image("java-selection.Dockerfile", target=target) as image:
            with running_container(image) as container:
                settings = container.output("java", "-XshowSettings:properties", "-version")
                self.assertRegex(settings, rf"(?m)^\s*java.vendor = {re.escape(vendor)}$")
                self.assertRegex(container.output("javac", "-version"), r"\bjavac 21(?:\.|$)")
                home = container.output("printenv", "JAVA_HOME")
                javac = container.output("bash", "-c", "command -v javac")
                self.assertEqual(container.output("readlink", "-f", f"{home}/bin/javac"), container.output("readlink", "-f", javac))

    def test_select_temurin_with_openjdk_already_installed(self):
        self.verify_provider("temurin", "Eclipse Adoptium")

    def test_select_openjdk_with_temurin_already_installed(self):
        self.verify_provider("openjdk-again", "Debian")


if __name__ == "__main__":
    unittest.main()
