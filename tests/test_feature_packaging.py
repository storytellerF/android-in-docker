from pathlib import Path
import tempfile
import unittest
import sys

from support import ROOT, clean_source_env, run


class FeaturePackagingTests(unittest.TestCase):
    def test_shared_helper_is_packaged_into_each_standalone_feature(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "features"
            run([sys.executable, ROOT / "scripts/prepare-feature-release.py", "--namespace", "example/android-in-docker", "--output", output])
            canonical = (ROOT / "features/_common/source-selection.sh").read_bytes()
            self.assertFalse((output / "_common").exists())
            for feature in ("java", "nodejs", "python"):
                with self.subTest(feature=feature):
                    packaged = output / feature / "source-selection.sh"
                    self.assertEqual(packaged.read_bytes(), canonical)
                    result = run(["bash", "-c", '. "$1"; SOURCE=default; resolve_feature_source JAVA_SOURCE; printf "%s" "$FEATURE_SELECTED_SOURCE"', "bash", packaged])
                    self.assertEqual(result.stdout, "default")
                    entry = run(["bash", output / feature / "install.sh"], env=clean_source_env(SOURCE="invalid"), check=False)
                    self.assertNotEqual(entry.returncode, 0)
                    self.assertIn("Invalid Feature source", entry.stdout)


if __name__ == "__main__":
    unittest.main()
