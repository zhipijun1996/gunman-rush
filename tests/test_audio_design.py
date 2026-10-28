"""Counterexamples for source binding and partial SFX rebuilds, in disposable copies."""
import contextlib
import importlib.util
import io
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class AudioDesignFingerprintTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="audio-design-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        manifest_name = "assets/audio/director_candidates/manifest.json"
        manifest = json.loads((ROOT / manifest_name).read_text())
        paths = {"tools/audio_design.py", "config/audio_director/recipes.json",
                 "config/audio_director/sources.json", manifest_name}
        paths.update(source["path"] for source in manifest["sources"].values())
        paths.update(take["path"].removeprefix("res://") for event in manifest["events"]
                     for candidate in event["candidates"] for take in candidate["renders"])
        for name in paths:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        spec = importlib.util.spec_from_file_location("audio_design_test_copy", self.root / "tools/audio_design.py")
        self.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)
        self.manifest_path = self.module.DEST / "manifest.json"

    def test_unchanged_complete_library_validates(self):
        with contextlib.redirect_stdout(io.StringIO()) as capture:
            self.module.validate()
        self.assertIn("events=16 rendered_files=64", capture.getvalue())

    def test_recipe_registry_and_pipeline_mutation_rejected(self):
        for name, key in [("config/audio_director/recipes.json", "recipe_sha256"),
                          ("config/audio_director/sources.json", "sources_sha256"),
                          ("tools/audio_design.py", "pipeline_sha256")]:
            with self.subTest(name=name):
                target = self.root / name
                original = target.read_bytes()
                target.write_bytes(original + b"\n")
                try:
                    with self.assertRaisesRegex(ValueError, key):
                        self.module.validate()
                finally:
                    target.write_bytes(original)

    def test_partial_drift_rejected_before_any_write(self):
        before = {path: self.module.digest(path) for path in self.module.DEST.glob("*.wav")}
        manifest_before = self.manifest_path.read_bytes()
        for name in ["config/audio_director/recipes.json", "config/audio_director/sources.json", "tools/audio_design.py"]:
            with self.subTest(name=name):
                target = self.root / name
                original = target.read_bytes()
                target.write_bytes(original + b"\n")
                try:
                    with patch.object(self.module, "render", side_effect=AssertionError("render must not start")):
                        with self.assertRaisesRegex(ValueError, "full build"):
                            self.module.build("shot")
                    self.assertEqual(manifest_before, self.manifest_path.read_bytes())
                    self.assertEqual(before, {path: self.module.digest(path) for path in before})
                finally:
                    target.write_bytes(original)

    def test_raw_source_mutation_rejected(self):
        manifest = self.module.read_json(self.manifest_path)
        layer = manifest["events"][0]["candidates"][0]["renders"][0]["layers"][0]
        target = self.root / manifest["sources"][layer["resolved_source"]]["path"]
        target.write_bytes(target.read_bytes() + b"changed original")
        with self.assertRaisesRegex(ValueError, "Unlicensed or changed source"):
            self.module.validate()

    def test_manifest_cannot_replace_source_registry_snapshot(self):
        manifest = self.module.read_json(self.manifest_path)
        next(iter(manifest["sources"].values()))["author"] = "unverified replacement"
        self.manifest_path.write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError, "source snapshot"):
            self.module.validate()

    def test_clean_partial_build_retains_other_events_without_rebinding(self):
        before = self.module.read_json(self.manifest_path)
        hashes = {path.name: self.module.digest(path) for path in self.module.DEST.glob("*.wav")}
        with contextlib.redirect_stdout(io.StringIO()):
            self.module.build("shot")
        after = self.module.read_json(self.manifest_path)
        self.assertEqual(before, after)
        self.assertEqual(hashes, {path.name: self.module.digest(path) for path in self.module.DEST.glob("*.wav")})


if __name__ == "__main__":
    unittest.main()
