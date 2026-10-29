"""Home sound provenance, selection preservation and failed-render counterexamples."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))


class HomeDesignTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="home-design-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        recipe = json.loads((ROOT / "config/audio_director/home/recipes.json").read_text())
        sources = json.loads((ROOT / "config/audio_director/home/sources.json").read_text())["sources"]
        names = {"tools/audio_home_design.py", "tools/audio_ambience_design.py", "config/audio_director/home/recipes.json",
                 "config/audio_director/home/sources.json", "assets/audio/ambience_v1/home/manifest.json"}
        names.update(recipe["locked_inputs"])
        for source in sources.values():
            names.update(source[key] for key in ["path", "source_page_path", "license_path"])
            if "source_registry_path" in source:
                names.add(source["source_registry_path"])
        names.update("assets/audio/ambience_v1/home/" + row["id"] + ".wav" for row in recipe["details"])
        for name in names:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        spec = importlib.util.spec_from_file_location("home_design_copy", self.root / "tools/audio_home_design.py")
        self.design = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.design)
        self.manifest_path = self.design.DEST / "manifest.json"

    def test_complete_candidate_validates(self):
        with contextlib.redirect_stdout(io.StringIO()) as capture:
            self.design.validate()
        self.assertIn("details=8 selected_and_bgm_locked=true", capture.getvalue())

    def test_selected_and_music_bytes_are_locked(self):
        recipe = self.design.read(self.design.CONFIG / "recipes.json")
        for name in ["config/audio_director/ambience/user-selected.json", "assets/audio/ambience_v1/plains_a.ogg",
                     "assets/audio/ambience_v1/forest_a.ogg", "assets/audio/bgm/the_kindred_hearth.mp3"]:
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes()
                path.write_bytes(original + b"changed")
                try:
                    with self.assertRaisesRegex(ValueError, "Selected/BGM input drift"):
                        self.design.check_inputs()
                finally:
                    path.write_bytes(original)

    def test_original_and_license_bytes_are_locked(self):
        sources = self.design.read(self.design.CONFIG / "sources.json")["sources"]
        for name in [sources["fabric"]["path"], sources["wood_1"]["path"], sources["fabric"]["source_page_path"], sources["page_1"]["license_path"]]:
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes()
                path.write_bytes(original + b"changed")
                try:
                    with self.assertRaisesRegex(ValueError, "Home source/license drift"):
                        self.design.check_inputs()
                finally:
                    path.write_bytes(original)

    def test_inherited_license_metadata_cannot_be_replaced(self):
        registry_path = self.design.CONFIG / "sources.json"
        registry = self.design.read(registry_path)
        source = registry["sources"]["wood_1"]
        prior_registry = self.root / source["source_registry_path"]
        prior = self.design.read(prior_registry)
        prior["sources"][source["source_registry_id"]]["author"] = "replacement author"
        self.design.write(prior_registry, prior)
        source["source_registry_sha256"] = self.design.processing.sha(prior_registry)
        self.design.write(registry_path, registry)
        with self.assertRaisesRegex(ValueError, "Inherited source metadata differs"):
            self.design.check_inputs()

    def test_output_and_pipeline_drift_rejected(self):
        for name in ["assets/audio/ambience_v1/home/home_cloth_1.wav", "tools/audio_home_design.py", "tools/audio_ambience_design.py", "config/audio_director/home/recipes.json"]:
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes()
                path.write_bytes(original + b"\n")
                try:
                    with self.assertRaisesRegex(ValueError, "Home output byte drift|Home fingerprint drift"):
                        self.design.validate()
                finally:
                    path.write_bytes(original)

    def test_candidate_point_and_runtime_identity_are_bound(self):
        original = self.manifest_path.read_bytes()
        mutations = [lambda m: m["events"][0]["candidates"][0].update(id="forged"),
                     lambda m: m["point_events"][0].update(event="coin"),
                     lambda m: m["regions"]["home"]["profiles"]["A"].update(gain_db=-12),
                     lambda m: m["bed_reference"].update(sha256="fake"),
                     lambda m: m["renders"][0].update(source_ids=["page_1"]),
                     lambda m: m.update(runtime_default="A"),
                     lambda m: m.update(channels=1),
                     lambda m: m["renders"].pop()]
        for mutate in mutations:
            self.manifest_path.write_bytes(original)
            manifest = self.design.read(self.manifest_path)
            mutate(manifest)
            self.design.write(self.manifest_path, manifest)
            with self.assertRaises(ValueError):
                self.design.validate()

    def test_source_changed_during_render_never_replaces_outputs_or_manifest(self):
        before_manifest = self.manifest_path.read_bytes()
        paths = list(self.design.DEST.glob("*.wav"))
        before_outputs = {path.name: path.read_bytes() for path in paths}
        source = self.design.read(self.design.CONFIG / "sources.json")["sources"]["fabric"]
        original = self.root / source["path"]
        render = self.design.render
        changed = False

        def changing_render(*args):
            nonlocal changed
            result = render(*args)
            if not changed:
                original.write_bytes(original.read_bytes() + b"changed while rendering")
                changed = True
            return result

        with patch.object(self.design, "render", side_effect=changing_render):
            with self.assertRaisesRegex(ValueError, "Home source/license drift"):
                self.design.build()
        self.assertTrue(changed)
        self.assertEqual(before_manifest, self.manifest_path.read_bytes())
        self.assertEqual(before_outputs, {path.name: path.read_bytes() for path in paths})

    def test_rebuild_is_exact_and_never_rewrites_selected_inputs(self):
        recipe = self.design.read(self.design.CONFIG / "recipes.json")
        locked_before = {name: self.design.processing.sha(self.root / name) for name in recipe["locked_inputs"]}
        before = {path.name: path.read_bytes() for path in self.design.DEST.glob("*.wav")}
        manifest_before = self.manifest_path.read_bytes()
        with contextlib.redirect_stdout(io.StringIO()):
            self.design.build()
        self.assertEqual(before, {path.name: path.read_bytes() for path in self.design.DEST.glob("*.wav")})
        self.assertEqual(manifest_before, self.manifest_path.read_bytes())
        self.assertEqual(locked_before, {name: self.design.processing.sha(self.root / name) for name in recipe["locked_inputs"]})


if __name__ == "__main__":
    unittest.main()
