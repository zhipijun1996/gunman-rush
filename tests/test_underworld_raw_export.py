"""Underworld FileAccess consumers require explicit, SHA-bound raw PNG bytes."""
import configparser
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import subprocess
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
SPEC = importlib.util.spec_from_file_location("underworld_delivery", ROOT / "tools/underworld_delivery.py")
delivery = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(delivery)


class RawPack:
    def __init__(self, entries):
        self.entries = entries

    def read(self, name):
        return self.entries[name]


class UnderworldRawExportTests(unittest.TestCase):
    def test_game_underworld_consumers_are_included_with_existing_scripts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sources = {
                'scripts/underworld_plains/legacy.gd': 'extends Node\n',
                'game/ui/current.gd': 'var icon = UnderworldUI.icon("heart")\n',
                'game/art/texture.gd': 'var path = "res://assets/underworld_plains/terrain/source.png"\n',
                'game/unrelated.gd': 'extends Node\n',
            }
            for name, code in sources.items():
                path = root/name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(code)
            with patch.object(delivery, 'ROOT', root):
                actual = {p.relative_to(root).as_posix() for p in delivery.underworld_script_consumers()}
                self.assertEqual(actual, set(sources)-{'game/unrelated.gd'})
                (root/'game/ui/current.gd').write_text('extends Node\n')
                self.assertNotIn(root/'game/ui/current.gd', delivery.underworld_script_consumers())


    def test_experiment_underworld_consumers_are_included_with_existing_scripts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            sources = {
                'scripts/underworld_plains/legacy.gd': 'extends Node\n',
                'experiments/ui/current.gd': 'var icon = UnderworldUI.icon("heart")\n',
                'experiments/art/texture.gd': 'var path = "res://assets/underworld_plains/terrain/source.png"\n',
                'experiments/unrelated.gd': 'extends Node\n',
            }
            for name, code in sources.items():
                path = root/name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(code)
            with patch.object(delivery, 'ROOT', root):
                actual = {p.relative_to(root).as_posix() for p in delivery.underworld_script_consumers()}
                self.assertEqual(actual, set(sources)-{'experiments/unrelated.gd'})
                (root/'experiments/ui/current.gd').write_text('extends Node\n')
                self.assertNotIn(root/'experiments/ui/current.gd', delivery.underworld_script_consumers())

    def test_game_dirty_or_untracked_source_blocks_frozen_delivery(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            actor = root/'game/actors/current.gd'
            actor.parent.mkdir(parents=True)
            actor.write_text('extends Node\n')
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
            git('init', '-q')
            git('add', '.')
            git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture')
            args = SimpleNamespace(source=git('rev-parse', 'HEAD'), bundle=root/'unused-bundle')
            with patch.object(delivery, 'ROOT', root):
                actor.write_text('extends Node2D\n')
                with self.assertRaisesRegex(ValueError, 'Runtime checkout is not the exact frozen source: game/'):
                    delivery.closure(args)
                git('checkout', '--', 'game/actors/current.gd')
                (actor.parent/'added.gd').write_text('extends Node\n')
                with self.assertRaisesRegex(ValueError, 'Runtime checkout is not the exact frozen source: game/'):
                    delivery.closure(args)


    def test_experiment_dirty_or_untracked_source_blocks_frozen_delivery(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            actor = root/'experiments/actors/current.gd'
            actor.parent.mkdir(parents=True)
            actor.write_text('extends Node\n')
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
            git('init', '-q')
            git('add', '.')
            git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'fixture')
            args = SimpleNamespace(source=git('rev-parse', 'HEAD'), bundle=root/'unused-bundle')
            with patch.object(delivery, 'ROOT', root):
                actor.write_text('extends Node2D\n')
                with self.assertRaisesRegex(ValueError, 'Runtime checkout is not the exact frozen source: experiments/'):
                    delivery.closure(args)
                git('checkout', '--', 'experiments/actors/current.gd')
                (actor.parent/'added.gd').write_text('extends Node\n')
                with self.assertRaisesRegex(ValueError, 'Runtime checkout is not the exact frozen source: experiments/'):
                    delivery.closure(args)

    def test_game_scripts_and_shaders_must_exist_in_actual_pack_closure(self):
        from test_web_bundle import write_pack
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)/'repo'
            root.mkdir()
            bundle = Path(temporary)/'web'
            bundle.mkdir()
            entries = {}
            def local(name, data):
                path = root/name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            for index, name in enumerate(delivery.RAW_UNDERWORLD_PATHS):
                target = '.godot/imported/fixture_' + str(index) + '.ctex'
                entries[name] = b'fixture raw source'
                entries[name+'.import'] = ('[remap]\npath="res://' + target + '"\n').encode()
                entries[target] = b'fixture cooked texture'
            entries['assets/underworld_plains/fixture.tres'] = b'[gd_resource type="TileSet" format=3]\n'
            scripts = {'game/art/current.gd': b'class_name CurrentUnderworld\nextends Node\n',
                       'game/art/current.gdshader': b'shader_type canvas_item;\n'}
            entries.update(scripts)
            for name, data in entries.items():
                local(name, data)
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
            git('init', '-q')
            git('add', '.')
            git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'pack fixture')
            args = SimpleNamespace(source=git('rev-parse', 'HEAD'), bundle=bundle)
            def prepare(values):
                pack = bundle/'index.pck'
                write_pack(pack, list(values.items()))
                (bundle/'build-info.json').write_text(json.dumps({'source_commit':args.source,
                    'pack':pack.name, 'build_id':delivery.sha(pack)[:12], 'pack_bytes':pack.stat().st_size}))
            with patch.object(delivery, 'ROOT', root), patch.object(delivery, 'ASSETS', root/'assets/underworld_plains'):
                prepare(entries)
                checked = delivery.closure(args)['checked']['resources']
                self.assertLessEqual(set(scripts), set(checked))
                for missing in scripts:
                    with self.subTest(missing=missing):
                        prepare({name:data for name,data in entries.items() if name!=missing})
                        with self.assertRaisesRegex(ValueError, 'PCK missing runtime resource'):
                            delivery.closure(args)


    def test_experiment_scripts_and_shaders_must_exist_in_actual_pack_closure(self):
        from test_web_bundle import write_pack
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)/'repo'
            root.mkdir()
            bundle = Path(temporary)/'web'
            bundle.mkdir()
            entries = {}
            def local(name, data):
                path = root/name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            for index, name in enumerate(delivery.RAW_UNDERWORLD_PATHS):
                target = '.godot/imported/fixture_' + str(index) + '.ctex'
                entries[name] = b'fixture raw source'
                entries[name+'.import'] = ('[remap]\npath="res://' + target + '"\n').encode()
                entries[target] = b'fixture cooked texture'
            entries['assets/underworld_plains/fixture.tres'] = b'[gd_resource type="TileSet" format=3]\n'
            scripts = {'experiments/art/current.gd': b'class_name CurrentUnderworld\nextends Node\n',
                       'experiments/art/current.gdshader': b'shader_type canvas_item;\n'}
            entries.update(scripts)
            for name, data in entries.items():
                local(name, data)
            def git(*args):
                return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
            git('init', '-q')
            git('add', '.')
            git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid', 'commit', '-qm', 'pack fixture')
            args = SimpleNamespace(source=git('rev-parse', 'HEAD'), bundle=bundle)
            def prepare(values):
                pack = bundle/'index.pck'
                write_pack(pack, list(values.items()))
                (bundle/'build-info.json').write_text(json.dumps({'source_commit':args.source,
                    'pack':pack.name, 'build_id':delivery.sha(pack)[:12], 'pack_bytes':pack.stat().st_size}))
            with patch.object(delivery, 'ROOT', root), patch.object(delivery, 'ASSETS', root/'assets/underworld_plains'):
                prepare(entries)
                checked = delivery.closure(args)['checked']['resources']
                self.assertLessEqual(set(scripts), set(checked))
                for missing in scripts:
                    with self.subTest(missing=missing):
                        prepare({name:data for name,data in entries.items() if name!=missing})
                        with self.assertRaisesRegex(ValueError, 'PCK missing runtime resource'):
                            delivery.closure(args)

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
