"""Actual preference evidence plus isolated hostile mapping counterexamples."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("audio_reel_choices", ROOT / "tools/audio_reel_choices.py")
choices = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(choices)
SAVED = ROOT / "config/audio_director/selected"


class AudioReelChoicesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = (SAVED / "user-20261028.json").read_bytes()
        cls.payload = choices.read_json(cls.raw)
        cls.reels_path = SAVED / "reels-user-20261028.json"
        cls.reels = choices.read_json(cls.reels_path.read_bytes())
        cls.bank_path = ROOT / "assets/audio/director_v3/manifest.json"
        cls.bank = choices.read_json(cls.bank_path.read_bytes())

    def normalize(self, payload=None, reels=None, bank=None):
        return choices.normalize(payload if payload is not None else copy.deepcopy(self.payload),
                                 reels if reels is not None else copy.deepcopy(self.reels),
                                 bank if bank is not None else copy.deepcopy(self.bank), root=ROOT)

    def test_actual_thirteen_preferences_resolve_fourteen_without_invented_approval(self):
        result = self.normalize()
        self.assertEqual(len(self.payload["choices"]), 13)
        self.assertEqual(result["event_profiles"], {
            "coin": "A", "heal": "A", "chest_open": "A", "item_get": "C",
            "click": "C", "confirm": "C", "denied": "C", "enemy_hit": "B",
            "enemy_hurt": "B", "hurt": "C", "shot_pulse": "A",
            "shot_shuriken": "original", "shot_bomb": "original", "bomb_explode": "original"})
        events = {item["event_id"]: item for item in result["events"]}
        self.assertEqual(sum(item["user_selected"] for item in events.values()), 13)
        self.assertEqual(events["bomb_explode"]["selection_status"], "derived")
        self.assertEqual(events["bomb_explode"]["derived_from"]["event_id"], "shot_bomb")
        self.assertFalse(events["bomb_explode"]["user_selected"])
        self.assertIsNone(events["shot_bomb"]["candidate_path"])
        self.assertIsNone(events["shot_shuriken"]["candidate_sha256"])
        self.assertEqual(events["coin"]["candidate_path"], "res://assets/audio/director_v3/coin_a.wav")
        self.assertNotIn("original/step", events["coin"]["source_ids"])
        self.assertIn("original/step", events["coin"]["evidence"]["reel_source_ids"])
        self.assertEqual(events["click"]["candidate_id"], "click_c")
        self.assertEqual(events["click"]["evidence"]["reel_candidate_id"], "ui_c")

    def test_missing_choices_stay_unknown_original_and_ui_siblings_are_not_inferred(self):
        payload = copy.deepcopy(self.payload)
        payload["choices"] = [row for row in payload["choices"] if row["event_id"] not in ("coin", "confirm", "denied", "shot_bomb")]
        events = {row["event_id"]: row for row in self.normalize(payload)["events"]}
        for event in ("coin", "confirm", "denied", "shot_bomb", "bomb_explode"):
            with self.subTest(event=event):
                self.assertEqual(events[event]["profile"], "original")
                self.assertEqual(events[event]["selection_status"], "unknown")
                self.assertFalse(events[event]["user_selected"])
                self.assertIsNone(events[event]["derived_from"])
        self.assertEqual(events["click"]["profile"], "C")
        self.assertTrue(all(not r["user_selected"] for r in self.normalize({**payload, "choices": []})["events"]))

    def test_each_identity_and_version_binding_rejects_independent_tampering(self):
        for field, value in (("schema_version", 2), ("schema_version", True), ("task", "AUDIO-DIRECTOR-02"),
                             ("candidate_version", "audio-director-v2"), ("source_commit", "0" * 40),
                             ("exported_at", "yesterday")):
            with self.subTest(top=field, value=value):
                payload = copy.deepcopy(self.payload)
                payload[field] = value
                with self.assertRaises(ValueError):
                    self.normalize(payload)
        for field, value in (("clip_id", "ui"), ("clip_id", "not-a-clip"), ("event_id", "confirm"),
                             ("event_id", "not-a-sound"), ("candidate_id", "coin_b"),
                             ("sound_candidate_id", "coin_b"), ("profile", "B"),
                             ("video_version", "bgm"), ("version", "audio-director-v2"),
                             ("event_ids", ["heal"]), ("source_ids", ["original/step"]),
                             ("updated_at", "2099-01-01T00:00:00Z")):
            with self.subTest(row=field, value=value):
                payload = copy.deepcopy(self.payload)
                payload["choices"][0][field] = value
                with self.assertRaises(ValueError):
                    self.normalize(payload)
        for target in ("task", "version", "schema_version"):
            with self.subTest(evidence=target):
                reels = copy.deepcopy(self.reels)
                reels[target] = "wrong"
                with self.assertRaises(ValueError):
                    self.normalize(reels=reels)

    def test_duplicate_event_even_from_other_clip_is_rejected(self):
        payload = copy.deepcopy(self.payload)
        payload["choices"].append(copy.deepcopy(payload["choices"][0]))
        with self.assertRaisesRegex(ValueError, "Duplicate event choice"):
            self.normalize(payload)
        payload["choices"][-1]["clip_id"] = "mix"
        with self.assertRaisesRegex(ValueError, "Duplicate event choice"):
            self.normalize(payload)

    def test_times_must_match_exact_reel_intervals_and_be_finite(self):
        for field, value in (("start", -1), ("start", True), ("start", 3.1),
                             ("end", 999), ("end", 3), ("start", float("nan")),
                             ("end", float("inf")), ("end", float("-inf"))):
            with self.subTest(field=field, value=value):
                payload = copy.deepcopy(self.payload)
                payload["choices"][0][field] = value
                with self.assertRaises(ValueError):
                    self.normalize(payload)
        for raw in (b'{"x":NaN}', b'{"x":Infinity}', b'{"x":1e999}', b'{"x":1,"x":2}'):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                value = choices.read_json(raw)
                choices._finite_tree(value)

    def test_reel_event_route_audibility_and_bank_bytes_are_bound(self):
        for field, value in (("event_candidate_ids", {"coin": "heal_a"}),
                             ("event_candidate_ids", {"coin": "coin_missing"}),
                             ("audible_candidate_ids", [])):
            reels = copy.deepcopy(self.reels)
            segment = next(c for c in reels["clips"][0]["candidates"] if c["id"] == "coin_a")
            segment[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.normalize(reels=reels)
        for field, value in (("path", "res://assets/audio/director_v3/absent.wav"),
                             ("path", "res://assets/audio/director_v3/../../../AGENTS.md"),
                             ("sha256", "0" * 64), ("source_ids", ["original/step"]),
                             ("variants", ["res://assets/audio/director_v3/coin_b.wav"])):
            bank = copy.deepcopy(self.bank)
            bank["events"][0]["candidates"][0][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.normalize(bank=bank)

    def test_compound_bomb_original_derivation_is_narrow_and_conflicts_rejected(self):
        payload = copy.deepcopy(self.payload)
        bomb = payload["choices"][-1]
        bomb["event_id"] = "bomb_explode"
        bomb["sound_candidate_id"] = "bomb_explode_original"
        events = {e["event_id"]: e for e in self.normalize(payload)["events"]}
        self.assertEqual(events["shot_bomb"]["selection_status"], "derived")
        self.assertEqual(events["bomb_explode"]["selection_status"], "explicit")
        explicit_blast = copy.deepcopy(self.payload["choices"][-1])
        segment = next(c for clip in self.reels["clips"] if clip["id"] == "bomb_weapon"
                       for c in clip["candidates"] if c["profile"] == "A")
        explicit_blast.update(event_id="bomb_explode", candidate_id=segment["id"],
                              sound_candidate_id="bomb_explode_a", profile="A",
                              start=segment["start"], end=segment["end"], source_ids=segment["source_ids"])
        payload = copy.deepcopy(self.payload)
        payload["choices"].append(explicit_blast)
        with self.assertRaisesRegex(ValueError, "Conflicting original compound"):
            self.normalize(payload)
        payload["choices"] = [explicit_blast]
        events = {e["event_id"]: e for e in self.normalize(payload)["events"]}
        self.assertEqual(events["bomb_explode"]["profile"], "A")
        self.assertEqual(events["shot_bomb"]["selection_status"], "unknown")

    def test_explicit_abstention_or_rejection_is_not_candidate_approval(self):
        for candidate_id, status in ((None, "unknown"), ("", "unknown"), ("reject_all", "rejected")):
            payload = copy.deepcopy(self.payload)
            row = payload["choices"][0]
            row.update(candidate_id=candidate_id, sound_candidate_id=None, profile=None,
                       start=None, end=None, source_ids=[], event_ids=["coin"])
            event = self.normalize(payload)["events"][0]
            self.assertEqual(event["selection_status"], status)
            self.assertFalse(event["user_selected"])
            self.assertEqual(event["profile"], "original")

    def test_import_retains_exact_bytes_and_fingerprints_with_no_write_on_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "selected"
            source = Path(tmp) / "input.json"
            source.write_bytes(self.raw)
            result = choices.import_choices(source, self.reels_path, self.bank_path, out, root=ROOT)
            self.assertEqual((out / "user-20261028.json").read_bytes(), self.raw)
            self.assertEqual(result["provenance"]["input"]["sha256"], hashlib.sha256(self.raw).hexdigest())
            self.assertEqual(result["provenance"]["reels"]["sha256"], hashlib.sha256(self.reels_path.read_bytes()).hexdigest())
            self.assertEqual(result["provenance"]["candidate_manifest"]["sha256"], hashlib.sha256(self.bank_path.read_bytes()).hexdigest())
            before = (out / "selected.json").read_bytes()
            choices.import_choices(source, self.reels_path, self.bank_path, out, root=ROOT)
            self.assertEqual((out / "selected.json").read_bytes(), before)
            payload = copy.deepcopy(self.payload)
            payload["choices"][0]["sound_candidate_id"] = "coin_b"
            source.write_text(json.dumps(payload))
            with self.assertRaises(ValueError):
                choices.import_choices(source, self.reels_path, self.bank_path, out, root=ROOT)
            self.assertEqual((out / "selected.json").read_bytes(), before)
            self.assertEqual((out / "user-20261028.json").read_bytes(), self.raw)
            source.write_bytes(self.raw + b"\n")
            with self.assertRaisesRegex(ValueError, "Existing evidence differs"):
                choices.import_choices(source, self.reels_path, self.bank_path, out, root=ROOT)


if __name__ == "__main__":
    unittest.main()
