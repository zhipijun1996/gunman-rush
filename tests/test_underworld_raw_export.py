"""Underworld FileAccess consumers require explicit, SHA-bound raw PNG bytes."""
import configparser
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("underworld_delivery", ROOT / "tools/underworld_delivery.py")
delivery = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(delivery)


class RawPack:
    def __init__(self, entries):
        self.entries = entries

    def read(self, name):
        return self.entries[name]


class UnderworldRawExportTests(unittest.TestCase):
    def test_shipping_presets_list_exact_seven_paths_without_wildcards(self):
        presets = configparser.ConfigParser(interpolation=None)
        presets.read(ROOT / "export_presets.cfg")
        expected = set(delivery.RAW_UNDERWORLD_PATHS)
        self.assertEqual(len(expected), 7)
        for index in range(3):
            included = presets[f"preset.{index}"]["include_filter"].strip('"').split(",")
            actual = {name for name in included if name.startswith("assets/underworld_plains/") and name.endswith(".png")}
            self.assertEqual(actual, expected)

    def test_existing_manifest_sha_bindings_match_actual_bytes(self):
        assets = json.loads((ROOT / "assets/manifest.json").read_text())["assets"]
        bindings = {item["path"]: item["sha256"] for item in assets}
        terrain = json.loads((ROOT / "assets/underworld_plains/terrain/terrain_build.json").read_text())
        bindings[terrain["source_texture"].removeprefix("res://")] = terrain["source_sha256"]
        for name in delivery.RAW_UNDERWORLD_PATHS:
            self.assertEqual(bindings[name], hashlib.sha256((ROOT / name).read_bytes()).hexdigest())

    def test_imported_derivatives_do_not_substitute_for_raw_bytes(self):
        with self.assertRaisesRegex(ValueError, "raw PNG missing"):
            delivery.check_raw_sources(RawPack({name + ".import": b"mapped" for name in delivery.RAW_UNDERWORLD_PATHS}))

    def test_any_changed_raw_byte_is_rejected(self):
        values = {name: (ROOT / name).read_bytes() for name in delivery.RAW_UNDERWORLD_PATHS}
        self.assertEqual(len(delivery.check_raw_sources(RawPack(values))), 7)
        first = delivery.RAW_UNDERWORLD_PATHS[0]
        values[first] = values[first][:-1] + bytes([values[first][-1] ^ 1])
        with self.assertRaisesRegex(ValueError, "differs from source bytes"):
            delivery.check_raw_sources(RawPack(values))

    def test_exported_browser_requires_three_actual_nonempty_source_hashes(self):
        layers = [{"texture_path": "res://" + name, "texture_sha256": delivery.sha(ROOT / name)}
                  for name in delivery.RAW_UNDERWORLD_PATHS[:3]]
        line = "PIXEL_INSPECT " + json.dumps({"parallax": layers})
        self.assertEqual(len(delivery.check_parallax_hashes([line])), 3)
        layers[0]["texture_sha256"] = ""
        with self.assertRaisesRegex(ValueError, "missing or wrong"):
            delivery.check_parallax_hashes(["PIXEL_INSPECT " + json.dumps({"parallax": layers})])
        with self.assertRaisesRegex(ValueError, "all three"):
            delivery.check_parallax_hashes([])

    def test_cooked_font_requires_matching_fontfile_mapping_and_bytes(self):
        name = "assets/fonts/fixture.otf"
        target = ".godot/imported/fixture.otf.fontdata"
        mapping = f'[remap]\ntype="FontFile"\npath="res://{target}"\n'
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / name
            source.parent.mkdir(parents=True)
            source.write_bytes(b"unit-source-font")
            source.with_suffix(".otf.import").write_text(mapping)
            cooked = root / target
            cooked.parent.mkdir(parents=True)
            cooked.write_bytes(b"unit-cooked-font")
            with patch.object(delivery, "ROOT", root):
                values = {name + ".import": mapping.encode(), target: cooked.read_bytes()}
                self.assertEqual(delivery.check_imported_font(RawPack(values), name)["imported_target"], target)
                values[target] += b"changed"
                with self.assertRaisesRegex(ValueError, "cooked bytes differ"):
                    delivery.check_imported_font(RawPack(values), name)
                values[name + ".import"] = mapping.replace("FontFile", "Texture2D").encode()
                with self.assertRaisesRegex(ValueError, "not FontFile"):
                    delivery.check_imported_font(RawPack(values), name)


if __name__ == "__main__":
    unittest.main()
