import os
from pathlib import Path
import shutil
import tempfile
import unittest

from support import ROOT, run


class AndroidStartupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="android-startup-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        (self.home / "bin").mkdir()
        for name in ("install-sdk", "create-avd", "start-avd"):
            path = self.home / "bin" / f"{name}.sh"
            shutil.copyfile(ROOT / "tests/fixtures/android_step.py", path)
            path.chmod(0o755)
        self.log = self.home / "steps"

    def start(self, **values):
        env = os.environ.copy()
        env.pop("FAIL_SDK", None)
        env.update(HOME=str(self.home), STARTUP_LOG=str(self.log), **values)
        return run(["bash", ROOT / "base-scripts/start-android.sh"], env=env, check=False)

    def test_sdk_avd_emulator_order_preserves_profile_argument(self):
        profile = str(self.home / "custom profile")
        result = self.start(ANDROID_PROFILE=profile)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.log.read_text().splitlines(), ["install-sdk:", f"create-avd:{profile}", f"start-avd:{profile}"])

    def test_sdk_failure_stops_startup_and_preserves_exit_code(self):
        result = self.start(FAIL_SDK="true")
        self.assertEqual(result.returncode, 7, result.stdout)
        self.assertEqual(self.log.read_text().splitlines(), ["install-sdk:"])


if __name__ == "__main__":
    unittest.main()
