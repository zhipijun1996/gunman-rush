"""Adversarial offline pipeline checks. Synthetic traces are reader tests only."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import level_content as content
import level_content_pilot as pilot
import level_content_search as search
import run_level_content_tests as runner
import level_content_export as exporter


def document():
    return {"objects": [{"id": "ground", "type": "terrain", "x": 20, "y": 50,
                         "width": 300, "height": 20, "label": "ground"}],
            "source": {"commit": "a" * 40, "path": "source.tres", "kind": "resource",
                       "editorTranslation": [20, 30], "original": {}}, "routes": []}


def frame(x=0, vx=0, grounded=True, actions=()):
    return {"position": [x, 0], "velocity": [vx, 0], "grounded": grounded,
            "accepted_actions": [{"type": action} for action in actions]}


ENGINE_FORMAT_FIXTURE = {"version": "4.7.2.stable.official.format-test",
                         "binary_sha256": "b" * 64, "bytes": 10, "binary": "/format-test/not-an-engine"}


def dynamic_document():
    value = document()
    value["objects"] += [
        {"id": "ferry", "type": "platform", "x": 80, "y": 60, "width": 40, "height": 10, "trackId": "track"},
        {"id": "track", "type": "trackLine", "x": 80, "y": 60, "duration": 2,
         "points": [{"x": 80, "y": 60}, {"x": 200, "y": 90}], "targetId": "ferry"},
        {"id": "bell", "type": "bell", "x": 40, "y": 40, "targetId": "door-a"},
        {"id": "door-a", "type": "door", "x": 200, "y": 50, "width": 20, "height": 80},
        {"id": "door-b", "type": "door", "x": 400, "y": 50, "width": 20, "height": 80}]
    return value


class ContentPipelineTests(unittest.TestCase):
    def test_exporter_rejects_any_claimed_positive_without_its_own_bound_proof(self):
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'config').mkdir()
            (root / 'config/level_pilot_candidates.json').write_text('{"candidates":[]}')
            native = root / 'native.json'
            native.write_text('{"passed":true}')
            analysis = root / 'analysis.json'
            analysis.write_text('{"modules":[]}')
            report = root / 'experiment.json'
            report.write_text(json.dumps({'source_commit': 'a' * 40, 'results': [
                {'id': 'plains_overlook_choice', 'variant': 0, 'condition': 'reward', 'ok': True,
                 'raw_path': 'native.json', 'raw_sha256': content.sha(native)}]}))
            args = SimpleNamespace(analysis=str(analysis), pilot=str(report), output=str(root / 'build/out'))
            with patch.object(exporter, 'ROOT', root), patch.object(exporter, 'verified_result', return_value=False):
                with self.assertRaisesRegex(ValueError, 'positive native proof rejected'):
                    exporter.build(args)

    def test_labels_and_ids_do_not_manufacture_geometry_novelty(self):
        a = document()
        b = copy.deepcopy(a)
        b["objects"][0].update(id="novel-clock-root", label="genius new mechanic", note="novel")
        self.assertEqual(content.features(a)["geometry_signature"], content.features(b)["geometry_signature"])
        b["objects"][0]["width"] += 1
        self.assertNotEqual(content.features(a)["geometry_signature"], content.features(b)["geometry_signature"])

    def test_editor_translation_is_not_geometry_change(self):
        a, b = document(), document()
        b["source"]["editorTranslation"] = [100, 200]
        b["objects"][0].update(x=100, y=220)
        self.assertEqual(content.features(a)["geometry_signature"], content.features(b)["geometry_signature"])

    def test_different_dynamic_parameters_remain_different(self):
        a, b = document(), document()
        a["objects"][0].update(type="trackLine", duration=2, points=[[20, 50], [300, 50]])
        b["objects"][0].update(type="trackLine", duration=4, points=[[20, 50], [300, 50]])
        self.assertNotEqual(content.features(a)["geometry_signature"], content.features(b)["geometry_signature"])

    def test_track_object_and_target_id_renaming_preserves_geometry_and_intent(self):
        a, b = dynamic_document(), dynamic_document()
        mapping = {obj["id"]: "renamed-" + obj["id"] for obj in b["objects"]}
        for obj in b["objects"]:
            obj["id"] = mapping[obj["id"]]
            for key in ("trackId", "targetId"):
                if key in obj:
                    obj[key] = mapping[obj[key]]
        for signature in ("geometry_signature", "intent_signature"):
            self.assertEqual(content.features(a)[signature], content.features(b)[signature])

    def test_all_objects_and_track_points_translate_with_editor_origin(self):
        a, b = dynamic_document(), dynamic_document()
        dx, dy = 173, -91
        b["source"]["editorTranslation"] = [20 + dx, 30 + dy]
        for obj in b["objects"]:
            obj["x"] += dx
            obj["y"] += dy
            for point in obj.get("points", []):
                point["x"] += dx
                point["y"] += dy
        for signature in ("geometry_signature", "intent_signature"):
            self.assertEqual(content.features(a)[signature], content.features(b)[signature])

    def test_changing_bell_target_changes_relationship_but_not_geometry(self):
        a, b = dynamic_document(), dynamic_document()
        next(obj for obj in b["objects"] if obj["id"] == "bell")["targetId"] = "door-b"
        self.assertEqual(content.features(a)["geometry_signature"], content.features(b)["geometry_signature"])
        self.assertNotEqual(content.features(a)["intent_signature"], content.features(b)["intent_signature"])

    def test_observed_family_uses_accepted_events_instead_of_labels(self):
        a = [frame(), frame(30, 300, False, ["jump_executed"]), frame(60, 300, True)]
        b = copy.deepcopy(a)
        for row in b:
            row.update(label="new mechanic", design_family="hidden treasure")
        self.assertEqual(content.behavior(a)["behavior_family"], content.behavior(b)["behavior_family"])
        b[1]["accepted_actions"] = [{"type": "shot_fired"}]
        self.assertNotEqual(content.behavior(a)["behavior_family"], content.behavior(b)["behavior_family"])

    def test_requested_but_rejected_action_does_not_enter_behavior(self):
        frames = [frame(), frame(30, 200, True)]
        for row in frames:
            row["requested_actions"] = [{"type": "recoil"}]
        self.assertEqual(content.behavior(frames)["accepted_action_sequence"], [])

    def test_router_rejections_are_separate_from_executed_actions(self):
        baseline = [frame(), frame(30, 200, False, ["jump_executed"]), frame(60, 200)]
        noisy = copy.deepcopy(baseline)
        noisy[1]["accepted_actions"].append({"type": "router_rejected", "reason": "missing_resource"})
        self.assertEqual(content.behavior(baseline)["accepted_action_sequence"],
                         content.behavior(noisy)["accepted_action_sequence"])
        self.assertEqual(content.behavior(baseline)["behavior_family"],
                         content.behavior(noisy)["behavior_family"])

    def test_reversal_and_landing_changes_form_distinct_measured_families(self):
        forward = [frame(), frame(50, 300), frame(100, 300)]
        returning = [frame(), frame(50, 300), frame(20, -300)]
        airborne = [frame(), frame(50, 300, False), frame(100, 300)]
        families = {content.behavior(v)["behavior_family"] for v in (forward, returning, airborne)}
        self.assertEqual(len(families), 3)

    def test_empty_behavior_trace_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Empty"):
            content.behavior([])

    def create_library(self, root):
        lib = root / "library"
        lib.mkdir()
        path = lib / "a.json"
        path.write_text(json.dumps(document()))
        catalog = {"sourceCommit": "a" * 40, "modules": [
            {"id": "a", "title": "A", "category": "平原", "collection": "test only",
             "file": "library/a.json", "contentSha256": content.sha(path),
             "integration": {"usage": "unverified"}}]}
        (lib / "catalog.json").write_text(json.dumps(catalog))
        return path, catalog

    def test_library_hash_mismatch_rejects_before_analysis(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path, _ = self.create_library(root)
            path.write_text(path.read_text() + " ")
            with self.assertRaisesRegex(ValueError, "hash mismatch"):
                content.analyze(root, root / "out")

    def test_mixed_source_commit_rejects_even_with_matching_file_hash(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            path, catalog = self.create_library(root)
            changed = document()
            changed["source"]["commit"] = "b" * 40
            path.write_text(json.dumps(changed))
            catalog["modules"][0]["contentSha256"] = content.sha(path)
            (root / "library/catalog.json").write_text(json.dumps(catalog))
            with self.assertRaisesRegex(ValueError, "Mixed source"):
                content.analyze(root, root / "out")

    def test_import_and_attributed_ai_review_never_become_physics_or_human_pass(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.create_library(root)
            report = content.analyze(root, root / "out")
            row = report["modules"][0]
            self.assertEqual(row["technical"]["status"], "unverified")
            self.assertIsNone(row["features"]["observed_behavior"])
            review = {"id": "a", "document_sha256": row["source"]["document_sha256"], "decision": "retain",
                      "role": "rest", "strengths": ["safe pause"], "problems": [], "improvement": [],
                      "counterfactual": "challenging it would defeat its rest role", "evidence_paths": [],
                      "uncertainty": "no human play evidence"}
            review_path = root / "reviews.json"
            review_path.write_text(json.dumps({"schema_version": 1, "reviewer": "unit-test-fixture", "reviews": [review]}))
            content.merge_reviews(root / "out/analysis.json", review_path, root / "reviewed.json")
            result = json.loads((root / "reviewed.json").read_text())["modules"][0]
            self.assertEqual(result["ai_design"]["status"], "reviewed")
            self.assertEqual(result["technical"]["status"], "unverified")
            self.assertEqual(result["human"]["status"], "unverified")
            review["document_sha256"] = "0" * 64
            review_path.write_text(json.dumps({"schema_version": 1, "reviewer": "unit-test-fixture", "reviews": [review]}))
            with self.assertRaisesRegex(ValueError, "Stale AI review"):
                content.merge_reviews(root / "out/analysis.json", review_path, root / "stale.json")
            self.assertFalse((root / "stale.json").exists())

    def test_empty_failure_not_admitted_to_archive_even_with_green_label(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "receipts.json"
            source.write_text(json.dumps({"results": [{"id": "fake", "ok": True, "frames": [], "errors": []}]}))
            content.archive(source, root / "archive.json")
            result = json.loads((root / "archive.json").read_text())
            self.assertEqual(result["cells"], [])
            self.assertEqual(result["candidates"], [])
            self.assertEqual(len(result["failure_feedback"]), 1)
            self.assertEqual(result["human"], "unverified")

    def test_nonempty_fake_physics_pass_stays_outside_archive_cells(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "receipts.json"
            source.write_text(json.dumps({"results": [{"id": "fake", "condition": "main", "ok": True,
                                                       "frames": [frame(), frame(30, 300)], "errors": []}]}))
            content.archive(source, root / "archive.json")
            result = json.loads((root / "archive.json").read_text())
            self.assertEqual(result["cells"], [])
            self.assertFalse(result["candidates"][0]["technical_ok"])
            self.assertEqual(result["candidates"][0]["evidence_status"], "unverified_or_failed")

    def test_archive_rejects_truncated_inventory_even_if_outer_hashes_are_refreshed(self):
        # Mocks isolate the source-closure reader. This fixture does not claim
        # a real Motor run; native-format and engine guards have separate tests.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "project.godot").write_text("format-test")
            (root / "tools").mkdir()
            (root / "tools/level_pilot_validate.gd").write_text("format-test")
            (root / "runner.py").write_text("runner")
            (root / "shared.gd").write_text("shared consumer")
            source = {name: content.sha(root / name) for name in ("runner.py", "shared.gd")}
            raw_path = root / "native.json"
            native = {"frames": [frame()], "runtime_consumer": "existing"}
            raw_path.write_text(json.dumps(native))
            request = {"candidate": "a", "strategy": "main", "variant": 0}
            receipt = {"raw_path": "native.json", "request": request, "runtime_source": source,
                       "technical_pass": True, "source_fingerprint": content.digest(source),
                       "identity": content.digest({"request": request, "runtime_bytes": source})}
            result = {"id": "a", "condition": "main", "variant": 0, "raw_path": "native.json", "ok": True,
                      "raw_sha256": content.sha(raw_path), "frames": native["frames"]}
            report = {"source_commit": "a" * 40, "source_fingerprint": content.digest(source), "receipts": [receipt]}
            with patch.object(pilot, "snapshot", return_value=source), \
                    patch.object(pilot, "cached_valid", return_value=True), \
                    patch("level_content_contract._physics_receipt", return_value=True):
                self.assertTrue(content.verified_result(report, result, root / "experiment.json"))
                changed = copy.deepcopy(report)
                truncated = {"runner.py": source["runner.py"]}
                changed["receipts"][0].update(runtime_source=truncated, source_fingerprint=content.digest(truncated),
                                               identity=content.digest({"request": request, "runtime_bytes": truncated}))
                changed["source_fingerprint"] = content.digest(truncated)
                self.assertFalse(content.verified_result(changed, result, root / "experiment.json"))

    def test_search_uses_same_seed_feedback_and_ignores_expected_no_jump_failure(self):
        # A synthetic archive shape tests selection semantics only. Real
        # archive generation independently demands native bound evidence.
        catalog = {"candidates": [{"id": cid, "gene": {"route_order": "reward_then_return_then_progress"}}
                                   for cid in ("plains_overlook_choice", "plains_backlook_cache",
                                               "forest_crown_root_choice", "forest_basin_homecoming")]}
        original = search.propose(catalog, 20261023)
        parents = lambda proposal: {c["parent"] for c in proposal["candidates"]}
        self.assertIn("plains_backlook_cache", parents(original))
        self.assertEqual(original, search.propose(catalog, 20261023))
        for condition in ("main", "reward"):
            failure = {"candidates": [{"id": "plains_backlook_cache", "technical_ok": False, "condition": condition}]}
            self.assertNotIn("plains_backlook_cache", parents(search.propose(catalog, 20261023, failure)))
        ablation = {"candidates": [{"id": "plains_backlook_cache", "technical_ok": False, "condition": "no_jump"}]}
        self.assertEqual(parents(original), parents(search.propose(catalog, 20261023, ablation)))

    def test_wrapper_rejects_green_summary_without_bound_native_evidence(self):
        for summary in ({"blocked": []}, {"blocked": [], "receipts": []},
                        {"blocked": ["failed"], "receipts": []}):
            with self.subTest(summary=summary), self.assertRaises(ValueError):
                runner.verify_pilot_summary(summary, {("a", "main", 0)})
        fake = {"blocked": [], "receipts": [{"request": {"candidate": "a", "strategy": "main", "variant": 0},
                                              "terminal": "completed", "source_stable": True,
                                              "technical_pass": True}]}
        with self.assertRaisesRegex(ValueError, "identity"):
            runner.verify_pilot_summary(fake, {("a", "main", 0)})

    def test_wrapper_rejects_duplicate_conditions_and_wrong_strategy(self):
        receipt = {"request": {"candidate": "a", "strategy": "reward", "variant": 0}}
        with self.assertRaisesRegex(ValueError, "Unexpected"):
            runner.verify_pilot_summary({"blocked": [], "receipts": [receipt]}, {("a", "main", 0)})

    def test_invalid_output_path_cannot_trigger_engine(self):
        with patch("run_tests.run_engine") as engine:
            for path in ("docs/evidence/wrong", "../outside", "/tmp/out"):
                with self.subTest(path=path), self.assertRaises(ValueError):
                    runner.run_pilot(path)
            engine.assert_not_called()

    def test_cache_raw_byte_mismatch_is_not_reused(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = {"stub.gd": hashlib.sha256(b"source").hexdigest()}
            request = {"candidate": "a", "strategy": "main", "variant": 0}
            identity = content.digest({"request": request, "runtime_bytes": source})
            folder = root / "build/cases"
            dest = folder / identity[:20]
            dest.mkdir(parents=True)
            raw = dest / "native.json"
            log = dest / "native.log"
            raw.write_text('{"passed":true,"frames":[{}]}')
            log.write_text("LEVEL PILOT: PASS\n")
            (dest / "receipt.json").write_text(json.dumps({"identity": identity, "terminal": "completed",
                                                          "raw_sha256": content.sha(raw), "log_sha256": content.sha(log)}))
            raw.write_text('{"passed":false,"frames":[{}]}')
            # Either retained refusal or a fresh attempt is legal. A reused
            # green receipt after changing raw bytes is not.
            with patch.object(pilot, "snapshot", return_value=source), \
                    patch.object(pilot, "engine_identity", return_value=ENGINE_FORMAT_FIXTURE), \
                    patch.object(pilot, "run_engine", side_effect=RuntimeError("unit no engine")):
                try:
                    receipt, _, reused = pilot.run_case(root, folder, request, source, reuse=True)
                except (FileExistsError, ValueError, OSError):
                    return
                self.assertFalse(reused)
                self.assertFalse(receipt.get("technical_pass"))

    def test_cache_checks_native_outcome_and_log_binding_even_after_outer_hash_refresh(self):
        # This is an isolated reader fixture, not a Godot run. The positive
        # format control makes each mutation exercise the intended rejection.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / "tools").mkdir()
            (root / "config").mkdir()
            producer = root / "tools/level_pilot_validate.gd"
            producer.write_bytes(b"format-test-not-gameplay")
            catalog = root / "config/pilot.json"
            catalog.write_bytes(b"{}")
            raw_path, log = root / "native.json", root / "native.log"
            request = {"candidate": "a", "strategy": "main", "variant": 0, "catalog": "config/pilot.json"}
            native = {"candidate": "a", "strategy": "main", "variant": 0, "frames": [{"format_test": True}],
                      "source_hash": content.sha(producer), "catalog_sha256": content.sha(catalog),
                      "passed": True, "ok": True, "exit_code": 0}

            def save(data, *, terminal="PASS", receipt_pass=True, clean=True, bind_raw=True,
                     physics_ok=True, current_engine=None):
                raw_path.write_text(json.dumps(data))
                text = f"LEVEL PILOT: {terminal} / a / main\n"
                if bind_raw:
                    text += "LEVEL PILOT RECEIPT_SHA256: " + content.sha(raw_path) + "\n"
                if not clean:
                    text += "ObjectDB instances leaked at exit\n"
                log.write_text(text)
                old = {"identity": "fixture", "terminal": "completed", "source_stable": True,
                       "technical_pass": receipt_pass, "raw_sha256": content.sha(raw_path),
                       "log_sha256": content.sha(log), "engine_identity": ENGINE_FORMAT_FIXTURE}
                with patch.object(pilot, "engine_identity", return_value=current_engine or ENGINE_FORMAT_FIXTURE), \
                        patch("level_content_contract._physics_receipt", return_value=physics_ok):
                    return pilot.cached_valid(old, raw_path, log, "fixture", request, root)

            self.assertTrue(save(native))
            self.assertFalse(save({**native, "passed": False, "ok": False, "exit_code": 1}, terminal="FAIL"))
            self.assertFalse(save({**native, "frames": []}))
            self.assertFalse(save({**native, "candidate": "other"}))
            self.assertFalse(save({**native, "strategy": "reward"}))
            self.assertFalse(save({**native, "source_hash": "0" * 64}))
            self.assertFalse(save({**native, "catalog_sha256": "0" * 64}))
            self.assertFalse(save(native, terminal="FAIL"))
            self.assertFalse(save(native, clean=False))
            self.assertFalse(save(native, bind_raw=False))
            self.assertFalse(save(native, physics_ok=False))
            self.assertFalse(save(native, current_engine={**ENGINE_FORMAT_FIXTURE, "binary_sha256": "c" * 64}))
            self.assertFalse(save(native, current_engine={**ENGINE_FORMAT_FIXTURE, "version": "4.7.2.stable.official.other"}))
            # A real completed refusal may be reused as a refusal. It remains
            # outside the positive-cell technical acceptance path.
            self.assertTrue(save({**native, "passed": False, "ok": False, "exit_code": 1},
                                 terminal="FAIL", receipt_pass=False))

    def test_runner_and_real_engine_identity_changes_invalidate_snapshot(self):
        # Test byte inventory without invoking a real binary. The runtime
        # engine_identity function keeps its strict 4.7.2 requirement intact.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            paths = ("project.godot", "tools/level_pilot_validate.gd", "tools/level_content_pilot.py",
                     "tools/level_content.py", "tools/run_tests.py", "tools/godot.sh",
                     "tests/branch_module_driver.gd", "tests/audio_teardown.gd",
                     "tests/plains_exploration_motion.gd", "tests/plains_interactive_motion.gd")
            for name in paths:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("format-test " + name)
            with patch.object(pilot, "engine_identity", return_value=ENGINE_FORMAT_FIXTURE):
                baseline = pilot.snapshot(root)
                for name in ("tools/run_tests.py", "tools/godot.sh"):
                    path = root / name
                    path.write_text(path.read_text() + " changed")
                    changed = pilot.snapshot(root)
                    self.assertNotEqual(content.digest(baseline), content.digest(changed))
                    self.assertNotEqual(baseline[name], changed[name])
                    baseline = changed
            with patch.object(pilot, "engine_identity", return_value={**ENGINE_FORMAT_FIXTURE,
                                                                       "binary_sha256": "c" * 64}):
                changed = pilot.snapshot(root)
            self.assertNotEqual(content.digest(baseline), content.digest(changed))
            self.assertNotEqual(baseline["build/ai_level_design_v1/engine-identity.json"],
                                changed["build/ai_level_design_v1/engine-identity.json"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
