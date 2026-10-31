"""Fault-focused source/loop/cross-reference checks for environmental audio."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("ambience_design", ROOT / "tools/audio_ambience_design.py")
DESIGN = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DESIGN)


class LoopTests(unittest.TestCase):
    def test_crossfade_retains_middle_and_wraps_recorded_tail(self):
        # Recorded-value stand-in, no generated signal is used by production.
        recorded = np.arange(28, dtype=np.float32).reshape(14, 2)
        loop = DESIGN.periodic_crossfade(recorded, 10, 4)
        np.testing.assert_equal(loop[4:], recorded[4:10])
        np.testing.assert_equal(loop[0], recorded[10])
        self.assertEqual(loop.shape, (10, 2))

    def test_short_source_and_empty_overlap_rejected(self):
        for frames, overlap in [(10, 0), (10, 10), (14, 2)]:
            with self.subTest(frames=frames, overlap=overlap), self.assertRaises(ValueError):
                DESIGN.periodic_crossfade(np.ones((14, 2)), frames, overlap)

    def test_silent_nonfinite_and_peak_guard(self):
        for x in [np.zeros((12, 2)), np.full((12, 2), np.nan)]:
            with self.assertRaises(ValueError):
                DESIGN.metrics(x)
        x = np.ones((1000, 2), dtype=np.float32)
        x[0] = 50
        normalized = DESIGN.normalize(x, -10, -9)
        self.assertLessEqual(DESIGN.metrics(normalized)["peak_dbfs"], -8.99999)


class FingerprintTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ambience-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        names = ["tools/audio_ambience_design.py", "config/audio_director/ambience/sources.json",
                 "config/audio_director/ambience/recipes.json"]
        names += [str(p.relative_to(ROOT)) for p in (ROOT / "assets/audio/ambience_v1").rglob("*") if p.is_file() and not p.name.endswith(".import")]
        for name in names:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        spec = importlib.util.spec_from_file_location("ambience_copy", self.root / "tools/audio_ambience_design.py")
        self.design = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.design)
        self.manifest_path = self.design.DEST / "manifest.json"

    def mutate_manifest(self, mutate):
        m = self.design.read(self.manifest_path)
        mutate(m)
        self.manifest_path.write_text(json.dumps(m))

    def test_missing_original_cache_does_not_block_runtime_validation(self):
        # Runtime delivery has the exact derivatives and license proofs. Full
        # 160MB source cache is deliberately not required in the game checkout.
        self.design.validate()

    def test_present_corrupt_original_rejected(self):
        source = next(iter(self.design.read(self.design.CONFIG / "sources.json")["sources"].values()))
        path = self.root / source["path"]
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"corrupt cache")
        with self.assertRaisesRegex(ValueError, "Original missing/changed"):
            self.design.check_sources()

    def test_license_evidence_drift_rejected(self):
        source = next(iter(self.design.read(self.design.CONFIG / "sources.json")["sources"].values()))
        path = self.root / source["source_page_path"]
        path.write_bytes(path.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "License evidence changed"):
            self.design.check_sources()

    def test_original_mutation_during_render_rejected_before_manifest(self):
        registry_path = self.design.CONFIG / "sources.json"
        registry = self.design.read(registry_path)
        for source in registry["sources"].values():
            path = self.root / source["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fingerprinted original input")
            source.update(sha256=self.design.sha(path), bytes=path.stat().st_size)
        self.design.write(registry_path, registry)
        recipe_path = self.design.CONFIG / "recipes.json"
        recipe = self.design.read(recipe_path)
        recipe.update(sample_rate=1000, loop_seconds=0.01, crossfade_seconds=0.002)
        self.design.write(recipe_path, recipe)
        before = self.manifest_path.read_bytes()
        real_layer = self.design.layer_decode
        mutated = False

        def changing_layer(row, sources, rate, seconds):
            nonlocal mutated
            samples = real_layer(row, sources, rate, seconds)
            if not mutated:
                original = self.root / sources[row["source"]]["path"]
                original.write_bytes(original.read_bytes() + b"changed while rendering")
                mutated = True
            return samples

        def fake_encode(samples, path, rate):
            path.write_bytes(b"derivative")

        with patch.object(self.design, "decode", return_value=np.ones((20, 2), dtype=np.float32)), \
             patch.object(self.design, "encode", side_effect=fake_encode), \
             patch.object(self.design, "layer_decode", side_effect=changing_layer):
            with self.assertRaisesRegex(ValueError, "Original missing/changed"):
                self.design.build()
        self.assertTrue(mutated)
        self.assertEqual(self.manifest_path.read_bytes(), before)

    def test_config_pipeline_and_output_drift_rejected(self):
        for name in ["config/audio_director/ambience/recipes.json", "config/audio_director/ambience/sources.json", "tools/audio_ambience_design.py", "assets/audio/ambience_v1/plains_a.ogg"]:
            with self.subTest(name=name):
                path = self.root / name
                original = path.read_bytes()
                path.write_bytes(original + b"\n")
                try:
                    with self.assertRaisesRegex(ValueError, "Fingerprint drift|Output fingerprint changed"):
                        self.design.validate()
                finally:
                    path.write_bytes(original)

    def test_source_snapshot_and_runtime_path_drift_rejected(self):
        original = self.manifest_path.read_bytes()
        mutations = [lambda m: m["sources"]["park_wind"].update(author="different"),
                     lambda m: m["regions"]["plains"]["profiles"]["A"].update(bed="res://missing.ogg"),
                     lambda m: m["regions"]["forest"]["profiles"]["B"]["details"][0].update(path="res://wrong.wav"),
                     lambda m: m["events"][0]["candidates"][0].update(path="res://other.ogg"),
                     lambda m: m["events"][0]["candidates"][0].update(id="forged-candidate-id"),
                     lambda m: m["events"][0]["candidates"][0].update(loop=False),
                     lambda m: m["events"][0]["candidates"][0].update(duration=99),
                     lambda m: m["point_events"][0].update(event="coin"),
                     lambda m: m["renders"].pop()]
        for mutate in mutations:
            self.manifest_path.write_bytes(original)
            self.mutate_manifest(mutate)
            with self.assertRaisesRegex(ValueError, "Source snapshot|reference changed|Incomplete"):
                self.design.validate()


if __name__ == "__main__":
    unittest.main()
