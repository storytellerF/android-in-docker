import os
from pathlib import Path
import tempfile
import unittest

from support import ROOT, run


class JavaHomeTests(unittest.TestCase):
    def test_package_global_alternatives_do_not_override_its_jdk(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary) / "requested-jdk"
            (home / "bin").mkdir(parents=True)
            for name in ("java", "javac"):
                binary = home / "bin" / name
                binary.write_text("#!/bin/sh\nexit 0\n")
                binary.chmod(0o755)
            output = Path(temporary) / "selected-home"
            result = run(["bash", "-c", 'printf "%s\\n" /usr/bin/javac "$1/bin/javac" | bash "$2"',
                          "bash", home, ROOT / "features/java/record-home.sh"],
                         env={**os.environ, "JDK_HOME_FILE": str(output)})
            self.assertEqual(result.returncode, 0)
            self.assertEqual(output.read_text().strip(), str(home.resolve()))


if __name__ == "__main__":
    unittest.main()
