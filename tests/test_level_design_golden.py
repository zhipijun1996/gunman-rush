"""Falsifiable evidence checks; synthetic tests never count as Motor execution."""
import copy
import contextlib
import hashlib
import io
import json
import shutil
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from level_design_golden import ROOT, SCOPE, bind_design_cards, inspect_batch, manifest_hash, run


class GoldenEvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "replays").mkdir()
        self.batch = {"schema": 1, "profile": "base", "basis": "a" * 64, "engine": "test_engine",
                      "requested": 6, "failures": 0, "assertions": 100, "validation_scope": SCOPE,
                      "accepted": [], "rejected": [], "itineraries": [], "connection_proofs": []}
        templates = ["height_then_precision", "resource_then_rhythm", "t2", "t3", "t4", "t5"]
        self.log = []
        for template in templates:
            m = {"schema": 1, "scope": "development_only", "basis": self.batch["basis"], "engine": self.batch["engine"],
                 "id": template + "-base-v0-p0", "template_id": template, "capability_profile": "base", "variant": 0,
                 "phase_index": 0, "seed": template, "nodes": [{"module_id": "test", "offset": [0, 0], "phase_index": 0}]}
            m["hash"] = manifest_hash(m)
            self.batch["accepted"].append({"manifest": m, "ticks": 1, "replay": self.record(m)})
            self.log.append(f'FOUNDRY ACCEPT {m["id"]} ticks=1 shots=0 repair=0')
        for index in range(6):
            seed = str(index)
            m = {"schema": 1, "scope": "development_only", "basis": self.batch["basis"], "engine": self.batch["engine"],
                 "kind": "itinerary", "id": "route-" + hashlib.sha256(seed.encode()).hexdigest()[:10], "seed": seed,
                 "capability_profile": "base", "phrases": [copy.deepcopy(e["manifest"]) for e in self.batch["accepted"][:3]],
                 "nodes": [{"module_id": "test"}] * 3}
            m["hash"] = manifest_hash(m)
            self.batch["itineraries"].append(m)
            self.batch["connection_proofs"].append({"ok": True, "phrase_ids": [p["id"] for p in m["phrases"]], "nodes": 3, "replay": self.record(m)})
        self.log.append("FOUNDRY: accepted=6 rejected_attempts=0 failures=0")

    def tearDown(self):
        self.temp.cleanup()

    def record(self, m):
        r = {"schema": 1, "basis": m["basis"], "manifest_hash": m["hash"], "capability_profile": "base",
             "frames": [{"axis": 1, "position": [0, 0], "shots": 2, "actions": [{"type": "jump", "direction": [0, 0]}]}]}
        (self.root / "replays" / (m["id"] + ".json")).write_text(json.dumps(r))
        return {"ok": True, "ticks": 1, "max_position_error": 0}

    def inspect(self):
        path = self.root / "batch.json"
        path.write_text(json.dumps(self.batch))
        return inspect_batch(path, "\n".join(self.log), 6)

    def edit_replay(self, edit):
        m = self.batch["accepted"][0]["manifest"]
        p = self.root / "replays" / (m["id"] + ".json")
        r = json.loads(p.read_text())
        edit(r)
        p.write_text(json.dumps(r))

    def test_complete_evidence(self):
        self.assertEqual(len(self.inspect()["records"]), 12)

    def test_failure_count_rejected(self):
        self.batch["failures"] = 1
        with self.assertRaisesRegex(ValueError, "incomplete or failed"): self.inspect()

    def test_missing_completion_rejected(self):
        self.log.pop()
        with self.assertRaisesRegex(ValueError, "completion marker"): self.inspect()

    def test_script_error_rejected(self):
        self.log.append("SCRIPT ERROR: failed")
        with self.assertRaisesRegex(ValueError, "script error"): self.inspect()

    def test_wrong_hash_rejected(self):
        self.edit_replay(lambda r: r.update(manifest_hash="b" * 64))
        with self.assertRaisesRegex(ValueError, "basis/hash"): self.inspect()

    def test_wrong_basis_rejected(self):
        self.edit_replay(lambda r: r.update(basis="b" * 64))
        with self.assertRaisesRegex(ValueError, "basis/hash"): self.inspect()

    def test_empty_frames_rejected(self):
        self.edit_replay(lambda r: r.update(frames=[]))
        with self.assertRaisesRegex(ValueError, "empty/oversized"): self.inspect()

    def test_partial_replay_rejected(self):
        self.batch["accepted"][0]["replay"]["ticks"] = 0
        with self.assertRaisesRegex(ValueError, "every input frame"): self.inspect()

    def test_missing_acceptance_rejected(self):
        self.log.pop(0)
        with self.assertRaisesRegex(ValueError, "per-manifest"): self.inspect()

    def test_checksum_tampering_rejected(self):
        self.batch["accepted"][0]["manifest"]["nodes"][0]["offset"] = [500, 0]
        with self.assertRaisesRegex(ValueError, "checksum"): self.inspect()

    def test_itinerary_binding_rejected(self):
        self.batch["connection_proofs"][0]["phrase_ids"].reverse()
        with self.assertRaisesRegex(ValueError, "proof binding"): self.inspect()

    def test_itinerary_failure_rejected(self):
        self.batch["connection_proofs"][0]["ok"] = False
        with self.assertRaisesRegex(ValueError, "proof binding"): self.inspect()

    def test_missing_routes_rejected(self):
        self.batch["itineraries"] = []
        with self.assertRaisesRegex(ValueError, "itinerary proofs"): self.inspect()

    def test_negative_resource_rejected(self):
        self.edit_replay(lambda r: r["frames"][0].update(shots=-1))
        with self.assertRaisesRegex(ValueError, "shot resource"): self.inspect()

    def test_nonfinite_position_rejected(self):
        self.edit_replay(lambda r: r["frames"][0].update(position=[float("nan"), 0]))
        with self.assertRaisesRegex(ValueError, "position"): self.inspect()

    def test_no_actions_rejected(self):
        self.edit_replay(lambda r: r["frames"][0].update(actions=[]))
        with self.assertRaisesRegex(ValueError, "no input actions"): self.inspect()

    def test_divergence_rejected(self):
        self.batch["accepted"][0]["replay"]["max_position_error"] = 0.06
        with self.assertRaisesRegex(ValueError, "divergence"): self.inspect()

    def test_missing_replay_rejected(self):
        next((self.root / "replays").glob("height*.json")).unlink()
        with self.assertRaisesRegex(ValueError, "missing replay"): self.inspect()

    def test_incomplete_accepted_rejected(self):
        self.batch["accepted"].pop()
        with self.assertRaisesRegex(ValueError, "coverage mismatch"): self.inspect()

    def test_capability_mismatch_rejected(self):
        self.edit_replay(lambda r: r.update(capability_profile="air_chain"))
        with self.assertRaisesRegex(ValueError, "capability mismatch"): self.inspect()

    def test_real_design_cards_bind_three_categories(self):
        result = bind_design_cards(ROOT / "tests/fixtures/level_design_v2/golden_challenges.json", self.inspect())
        self.assertEqual({r["design_card_id"] for r in result["golden_bindings"]}, {"ordinary", "advanced", "master"})
        for binding in result["golden_bindings"]:
            self.assertEqual(binding["challenge_contract_status"], "unverified")
            self.assertEqual(binding["binding_status"], "passed")
            self.assertNotIn("technical_status", binding)
            self.assertIn("action_order_and_alternatives", binding["unverified_contract_fields"])

    def test_wrong_card_count_rejected_even_without_static_validation(self):
        for count in [99, 2, True, 3.0]:
            with self.subTest(count=count):
                design = json.loads((ROOT / "tests/fixtures/level_design_v2/golden_challenges.json").read_text())
                next(card for card in design["challenges"] if card["id"] == "master")["foundry"]["phrase_count"] = count
                card_path = self.root / "cards.json"
                card_path.write_text(json.dumps(design))
                with patch("level_design_contracts.validate_design", return_value=[]), self.assertRaisesRegex(ValueError, "phrase_count"):
                    bind_design_cards(card_path, self.inspect())

    def test_wrong_itinerary_template_rejected_even_without_static_validation(self):
        design = json.loads((ROOT / "tests/fixtures/level_design_v2/golden_challenges.json").read_text())
        next(card for card in design["challenges"] if card["id"] == "master")["foundry"]["template_id"] = "height_then_precision"
        card_path = self.root / "cards.json"
        card_path.write_text(json.dumps(design))
        with patch("level_design_contracts.validate_design", return_value=[]), self.assertRaisesRegex(ValueError, "template"):
            bind_design_cards(card_path, self.inspect())

    def test_record_count_mismatch_with_actual_manifest_rejected(self):
        report = self.inspect()
        next(record for record in report["records"] if record["kind"] == "itinerary")["phrase_count"] = 99
        with self.assertRaisesRegex(ValueError, "metadata differs"):
            bind_design_cards(ROOT / "tests/fixtures/level_design_v2/golden_challenges.json", report)

    def test_batch_changed_after_inspection_rejected(self):
        report = self.inspect()
        (self.root / "batch.json").write_text('{}')
        with self.assertRaisesRegex(ValueError, "artifact changed"):
            bind_design_cards(ROOT / "tests/fixtures/level_design_v2/golden_challenges.json", report)

    def test_record_kind_mismatch_with_actual_manifest_rejected(self):
        report = self.inspect()
        record = report["records"][0]
        record.update(kind="itinerary", template_id="mixed", phrase_count=3)
        # Keep another valid ordinary record so the mismatch reaches the master binding.
        report["records"].insert(1, {**record, "kind": "template", "template_id": "height_then_precision", "phrase_count": 1})
        with self.assertRaisesRegex(ValueError, "differs from actual Manifest"):
            bind_design_cards(ROOT / "tests/fixtures/level_design_v2/golden_challenges.json", report)

    def test_design_card_missing_evidence_rejected(self):
        report = self.inspect()
        report["records"] = [r for r in report["records"] if r.get("template_id") != "resource_then_rhythm"]
        with self.assertRaisesRegex(ValueError, "no fresh evidence"):
            bind_design_cards(ROOT / "tests/fixtures/level_design_v2/golden_challenges.json", report)

    def test_command_failure_retains_failed_report(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            def fail_engine(*unused):
                print("FOUNDRY failure example")
                raise RuntimeError("Godot returned 1")
            with patch("level_design_golden.run_engine", side_effect=fail_engine):
                with self.assertRaisesRegex(RuntimeError, "Godot returned 1"):
                    run(SimpleNamespace(output=directory, count=6))
            report = json.loads((Path(directory) / "report.json").read_text())
            self.assertEqual(report["status"], "failed")
            self.assertFalse(report["fresh_execution"])
            self.assertEqual(report["exit_code"], 1)
            self.assertTrue((ROOT / report["log"]["path"]).is_file())

    def test_command_success_without_new_batch_rejected(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            # A stale success report cannot substitute for the newly allocated run's batch.
            (Path(directory) / "report.json").write_text('{"status":"passed"}')
            with patch("level_design_golden.run_engine", return_value="FOUNDRY: accepted=6 rejected_attempts=0 failures=0\n"):
                with self.assertRaises(OSError):
                    run(SimpleNamespace(output=directory, count=6))
            self.assertEqual(json.loads((Path(directory) / "report.json").read_text())["status"], "failed")

    def fixture_engine(self, arguments, timeout):
        self.assertEqual(timeout, 600)
        target = ROOT / next(arg.split("res://", 1)[1] for arg in arguments if arg.startswith("--output=res://"))
        target.write_text(json.dumps(self.batch))
        shutil.copytree(self.root / "replays", target.parent / "replays")
        output = "\n".join(self.log)
        print(output)
        return output

    def test_matching_source_snapshot_allows_fresh_evidence(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            with patch("level_design_golden.run_engine", side_effect=self.fixture_engine), patch("level_design_golden.source_files", return_value={"test": "before"}), contextlib.redirect_stdout(io.StringIO()):
                run(SimpleNamespace(output=directory, count=6))
            report = json.loads((Path(directory) / "report.json").read_text())
            self.assertTrue(report["fresh_execution"])
            self.assertEqual(report["source_changes"], [])

    def test_source_change_rejects_otherwise_valid_evidence(self):
        with tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
            with patch("level_design_golden.run_engine", side_effect=self.fixture_engine), patch("level_design_golden.source_files", side_effect=[{"test": "before"}, {"test": "after", "new": "added"}]):
                with self.assertRaisesRegex(ValueError, "Source changed"):
                    run(SimpleNamespace(output=directory, count=6))
            report = json.loads((Path(directory) / "report.json").read_text())
            self.assertFalse(report["fresh_execution"])
            self.assertEqual(report["status"], "failed")
            self.assertEqual(report["source_changes"], ["new", "test"])
            self.assertEqual(report["exit_code"], 0)  # successful engine is insufficient
            self.assertTrue((ROOT / report["batch"]["path"]).is_file())

    def test_early_error_and_timeout_preserve_streamed_log(self):
        for error in [RuntimeError("Godot emitted a script/shader error; aborted immediately"), subprocess.TimeoutExpired("test-engine", 600)]:
            with self.subTest(error=type(error).__name__), tempfile.TemporaryDirectory(dir=ROOT / "build") as directory:
                def fail_engine(*unused):
                    print("SCRIPT ERROR: deliberately injected watchdog failure")
                    raise error
                with patch("level_design_golden.run_engine", side_effect=fail_engine):
                    with self.assertRaises(type(error)):
                        run(SimpleNamespace(output=directory, count=6))
                report = json.loads((Path(directory) / "report.json").read_text())
                self.assertEqual(report["status"], "failed")
                self.assertFalse(report["fresh_execution"])
                self.assertIsNone(report["exit_code"])
                self.assertIn("deliberately injected", (ROOT / report["log"]["path"]).read_text())


if __name__ == "__main__":
    unittest.main()
