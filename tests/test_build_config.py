from pathlib import Path
import sys
import tempfile
import unittest

from support import ROOT
sys.path.insert(0, str(ROOT / "scripts"))
from build_config import argument_parser, read_env, write_env, resolve_config, resolve_runtime_config, validate_build_config


class BuildConfigTests(unittest.TestCase):
    def resolve(self, args=(), saved=None, env=None):
        return resolve_config(argument_parser().parse_args(args), saved or {}, env or {})

    def test_cli_precedes_environment_and_saved_configuration(self):
        config = self.resolve(("-j", "25", "--namespace", "cli"),
                              {"OPENJDK_VERSION": "17", "DOCKER_USERNAME": "saved"},
                              {"OPENJDK_VERSION": "21", "DOCKER_USERNAME": "environment"})
        self.assertEqual((config.jdk, config.namespace), ("25", "cli"))

    def test_switching_system_discards_another_systems_saved_version(self):
        config = self.resolve(("-s", "fedora"), {"BASE_SYSTEM": "debian", "BASE_VERSION": "trixie"})
        self.assertEqual((config.version, config.user), ("43", "user"))

    def test_timezone_override_controls_automatic_mirror_selection(self):
        config = self.resolve(("-z", "UTC"), {"TZ": "Asia/Shanghai", "USE_CN_ENV": "true"})
        self.assertFalse(config.china)

    def test_persisted_configuration_resolves_to_the_same_image(self):
        original = self.resolve(("--namespace", "example", "--cn-mirror", "-s", "ubuntu"))
        restored = self.resolve(saved=original.persisted())
        self.assertEqual(restored.image_ref, original.image_ref)
        self.assertEqual(restored.home, original.home)

    def test_dotenv_values_roundtrip_preserves_literals(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / ".env"
            values = {
                "VNC_PASSWD": "spaces $literal 'quote' \\path", "UNKNOWN_SETTING": "$(touch forbidden)",
                "TRAILING_BACKSLASH": "end\\", "BACKSLASH_QUOTE": "a\\'b", "DOUBLE_QUOTE": 'a"b',
                "DOLLARS": "$$ ${literal} $literal", "UNICODE": "测试路径\\",
            }
            write_env(path, values)
            self.assertEqual(read_env(path), values)

    def test_unquoted_shell_expressions_are_never_executed(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / ".env"
            marker = Path(temporary) / "unexpected"
            value = f"$(touch {marker})"
            path.write_text(f"CUSTOM={value}\n")
            self.assertEqual(read_env(path)["CUSTOM"], value)
            self.assertFalse(marker.exists())

    def test_dotenv_allows_comments_after_quoted_values(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / ".env"
            path.write_text("DOCKER_USERNAME='example' # namespace\nOPENJDK_VERSION=\"21\" # JDK\n")
            self.assertEqual(read_env(path), {"DOCKER_USERNAME": "example", "OPENJDK_VERSION": "21"})

    def test_local_and_namespaced_image_tags_share_one_reference(self):
        for namespace in ("", "example"):
            config = self.resolve(("--namespace", namespace, "--no-snapshot", "--latest"))
            self.assertIn(config.image_ref, config.tags())
            self.assertTrue(all(tag.startswith(config.repository + ":") for tag in config.tags()))

    def test_invalid_syntax_is_rejected_during_resolution(self):
        for args in (("-j", "bad"), ("--namespace", "UpperCase"), ("-v", "contains space")):
            with self.subTest(args=args), self.assertRaises(ValueError):
                self.resolve(args)

    def test_unavailable_recipes_are_rejected_before_building(self):
        for args in (("-s", "ubuntu", "-v", "resolute"), ("-s", "fedora", "-v", "44")):
            with self.subTest(args=args), self.assertRaises(ValueError):
                validate_build_config(self.resolve(args))

    def test_publishing_requires_a_namespace(self):
        with self.assertRaisesRegex(ValueError, "Publishing requires"):
            validate_build_config(self.resolve(), publish=True)

    def test_runtime_uses_recorded_artifact_without_installation_checks(self):
        saved = {"IMAGE_REF": "example/android:existing", "CONTAINER_HOME": "/home/legacy", "CONTAINER_USER": "legacy",
                 "BASE_SYSTEM": "fedora", "BASE_VERSION": "44", "OPENJDK_VERSION": "21"}
        for operation in ("-S", "-T"):
            with self.subTest(operation=operation):
                config = resolve_runtime_config(argument_parser().parse_args([operation]), saved, {})
                self.assertEqual(config.image_ref, saved["IMAGE_REF"])
                self.assertEqual((config.home, config.user), ("/home/legacy", "legacy"))

    def test_runtime_can_resolve_legacy_recipe_without_installation_checks(self):
        saved = {"BASE_SYSTEM": "fedora", "BASE_VERSION": "44", "OPENJDK_VERSION": "21", "IMAGE_TAG_TIME": "20261030182842", "TZ": "UTC"}
        config = resolve_runtime_config(argument_parser().parse_args(["-S"]), saved, {})
        self.assertEqual(config.image_ref, "android-in-docker:fedora-44-xfce-openjdk21-20261030182842")

    def test_explicit_image_options_override_recorded_runtime_reference(self):
        saved = self.resolve(("-s", "fedora")).persisted()
        config = resolve_runtime_config(argument_parser().parse_args(["-S", "-v", "44"]), saved, {})
        self.assertIn(":fedora-44-xfce-openjdk21-", config.image_ref)

    def test_timezone_override_keeps_the_recorded_image(self):
        saved = self.resolve(("--cn-mirror",)).persisted()
        config = resolve_runtime_config(argument_parser().parse_args(["-S", "-z", "UTC"]), saved, {})
        self.assertEqual(config.image_ref, saved["IMAGE_REF"])
        self.assertEqual(config.timezone, "UTC")


if __name__ == "__main__":
    unittest.main()
