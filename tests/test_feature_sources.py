import unittest

from support import ROOT, clean_source_env, run


class FeatureSourceTests(unittest.TestCase):
    def resolve(self, feature, values):
        return run([
            "bash", "-c", 'set -e; . "$1"; resolve_feature_source "$2"; printf "%s" "$FEATURE_SELECTED_SOURCE"',
            "bash", ROOT / "features/_common/source-selection.sh", f"{feature.upper()}_SOURCE",
        ], env=clean_source_env(**values), check=False)

    def test_source_selection_priority(self):
        for feature in ("java", "nodejs", "python"):
            cases = [
                ("china", {"TZ": "Asia/Shanghai"}),
                ("default", {"TZ": "Etc/UTC"}),
                ("default", {"SOURCE": "default", "TZ": "Asia/Shanghai"}),
                ("china", {"FEATURE_SOURCE": "china", "TZ": "Etc/UTC"}),
                ("default", {"FEATURE_SOURCE": "china", f"{feature.upper()}_SOURCE": "default", "TZ": "Asia/Shanghai"}),
                ("china", {"TIMEZONE": "Asia/Shanghai", "TZ": "Etc/UTC"}),
            ]
            for expected, values in cases:
                with self.subTest(feature=feature, values=values):
                    result = self.resolve(feature, values)
                    self.assertEqual(result.returncode, 0, result.stdout)
                    self.assertEqual(result.stdout, expected)

    def test_invalid_source_rejected(self):
        for feature in ("java", "nodejs", "python"):
            with self.subTest(feature=feature):
                result = self.resolve(feature, {"SOURCE": "invalid"})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Invalid Feature source", result.stdout)


if __name__ == "__main__":
    unittest.main()
