"""Shipping presets must feed the editor raw exporter the real consumer closure."""
import configparser
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("web_closure", ROOT / "tools/check_web_bundle.py")
closure = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(closure)


class RuntimeRawExportTests(unittest.TestCase):
    def test_every_shipping_preset_uses_exact_runtime_raw_set_and_real_family_sha(self):
        _, textures, _ = closure.runtime_contract(ROOT)
        expected = {name for name, data in textures.items() if data["raw"]}
        config = configparser.ConfigParser(interpolation=None)
        config.read(ROOT / "export_presets.cfg")
        for index in range(3):
            with self.subTest(preset=index):
                preset = config[f"preset.{index}"]
                included = preset["include_filter"].strip('"').split(",")
                actual = {path for path in included if (path.startswith(closure.SPACES) or path.startswith(closure.CONNECTED_ROOT)) and path.endswith(".png")}
                self.assertEqual(actual, expected)
                self.assertIn("addons/runtime_raw_export/*", preset["exclude_filter"].strip('"').split(","))
                for name in actual:
                    family = json.loads((ROOT / name).with_name("family.json").read_text())
                    self.assertEqual(family["path"].removeprefix("res://"), name)
                    self.assertEqual(hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), family["sha256"])

    def test_editor_plugin_is_enabled_with_a_real_editor_entrypoint(self):
        project = (ROOT / "project.godot").read_text()
        self.assertIn('enabled=PackedStringArray("res://addons/runtime_raw_export/plugin.cfg")', project)
        config = configparser.ConfigParser(interpolation=None)
        directory = ROOT / "addons/runtime_raw_export"
        config.read(directory / "plugin.cfg")
        self.assertTrue((directory / config["plugin"]["script"].strip('"')).is_file())


if __name__ == "__main__":
    unittest.main()
