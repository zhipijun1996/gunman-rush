"""Bounded migration guard unit cases; native evidence remains the runner's job."""
import copy
import hashlib
import json
import shutil
import tarfile
import tempfile
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import run_plains_encounter_policy_tests as runner


def reports():
    before = {"analysis_version": 1, "policy": {"observation": "same"}, "fingerprint": "before", "cases": []}
    for seed, index, strategy in runner.CASES:
        before["cases"].append({
            "case": {"root_seed": seed, "map_index": index, "strategy": strategy, "phase_wait_ticks": 0},
            "capture_contract_version": 1, "capability_basis": {"weapon": "pulse"},
            "physics_hz": 60, "captured_scope": "formal", "observer_basis": {"observer": "same"},
            "policy_basis": {"driver_sources": {"driver": "same"}, "encounter_policy": "kill_from_bank_v1",
                "reward_policy": "two_actual_medium_and_camp_v1", "content_differences": ["content"],
                "core_invariants": {**{p: pair[0] for p, pair in runner.HISTORICAL_CORE_BOUNDARY.items()}, "unchanged": "same"}}})
    after = copy.deepcopy(before); after["fingerprint"] = "after"
    for case in after["cases"]:
        case["policy_basis"]["core_invariants"].update({p: pair[1] for p, pair in runner.HISTORICAL_CORE_BOUNDARY.items()})
    return before, after


class BoundaryTests(unittest.TestCase):
    def setUp(self):
        self.before, self.after = reports()
        # Only report construction/provenance is mocked: the real strict comparator
        # still runs and must reject these synthetic unit bases.
        self.validation = patch.object(runner.experience, "validate_report", side_effect=lambda r: r)
        self.validation.start(); self.addCleanup(self.validation.stop)

    def test_exact_transition_is_not_comparable(self):
        result = runner.historical_boundary_rejection(self.before, self.after)
        self.assertEqual(result["status"], "not_comparable")
        self.assertEqual(result["strict_rejection"], runner.STRICT_POLICY_REJECTION)
        self.assertNotEqual(result["artifact_kind"], "level_experience_comparison")

    def test_unknown_core_change_rejected(self):
        self.after["cases"][0]["policy_basis"]["core_invariants"]["unchanged"] = "future"
        with self.assertRaisesRegex(ValueError, "unreviewed historical core"):
            runner.historical_boundary_rejection(self.before, self.after)

    def test_wrong_known_pair_rejected(self):
        self.after["cases"][1]["policy_basis"]["core_invariants"]["res://project.godot"] = "f" * 64
        with self.assertRaisesRegex(ValueError, "unreviewed historical core"):
            runner.historical_boundary_rejection(self.before, self.after)

    def test_driver_change_rejected(self):
        self.after["cases"][2]["policy_basis"]["driver_sources"]["driver"] = "new"
        with self.assertRaisesRegex(ValueError, "historical driver"):
            runner.historical_boundary_rejection(self.before, self.after)

    def test_missing_core_rejected(self):
        del self.after["cases"][0]["policy_basis"]["core_invariants"]["unchanged"]
        with self.assertRaisesRegex(ValueError, "core closure"):
            runner.historical_boundary_rejection(self.before, self.after)

    def test_partial_matrix_rejected(self):
        self.after["cases"].pop()
        with self.assertRaisesRegex(ValueError, "four-case"):
            runner.historical_boundary_rejection(self.before, self.after)

    def test_control_or_observation_change_rejected(self):
        for field in ("capture_contract_version", "capability_basis", "physics_hz", "captured_scope", "observer_basis"):
            with self.subTest(field=field):
                after = copy.deepcopy(self.after); after["cases"][3][field] = "changed"
                with self.assertRaisesRegex(ValueError, "control basis"):
                    runner.historical_boundary_rejection(self.before, after)
        self.after["policy"] = {"changed": True}
        with self.assertRaisesRegex(ValueError, "observation policy"):
            runner.historical_boundary_rejection(self.before, self.after)

    def test_unexpected_comparator_error_not_swallowed(self):
        with patch.object(runner.experience, "compare", side_effect=ValueError("unrelated failure")):
            with self.assertRaisesRegex(ValueError, "unrelated failure"):
                runner.historical_boundary_rejection(self.before, self.after)

    def test_unexpected_strict_acceptance_rejected(self):
        with patch.object(runner.experience, "compare", return_value={"verdict": "REVIEW"}):
            with self.assertRaisesRegex(ValueError, "unexpectedly accepted"):
                runner.historical_boundary_rejection(self.before, self.after)

    def test_report_validation_failure_preserved(self):
        with patch.object(runner.experience, "validate_report", side_effect=ValueError("bad evidence")):
            with self.assertRaisesRegex(ValueError, "bad evidence"):
                runner.historical_boundary_rejection(self.before, self.after)


class FrozenEndpointTests(unittest.TestCase):
    """Real portable bytes; no Godot or Git-history requirement for restoration."""
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temp.cleanup)
        cls.home = Path(cls.temp.name)
        cls.basis = runner.ROOT / Path(runner.HISTORICAL_MANIFEST).parent
        cls.base_dir = runner.ROOT / "docs/evidence/plains_redesign/frozen_v9"
        cls.base = runner.read(cls.base_dir / "manifest.json")
        cls.seed = cls.home / "base"
        cls.seed.mkdir()
        with tarfile.open(cls.base_dir / "source.tar.gz") as bundle:
            for member in bundle.getmembers():
                if member.isfile():
                    content = bundle.extractfile(member).read()
                    assert hashlib.sha256(content).hexdigest() == cls.base["members"][member.name]
                    destination = cls.seed / member.name
                    destination.parent.mkdir(parents=True,exist_ok=True)
                    destination.write_bytes(content)
        from run_plains_action_golden_tests import restore_frozen_assets
        restore_frozen_assets(runner.ROOT, cls.seed, cls.base_dir, cls.base)

    def candidate(self):
        folder=Path(tempfile.mkdtemp(dir=self.home))
        shutil.copytree(self.seed,folder / "project")
        return folder / "project"

    def test_real_endpoint_restores_without_git_history(self):
        project=self.candidate()
        with patch.object(runner.subprocess,"check_output",side_effect=AssertionError("No Git in shallow portable restore")):
            result=runner.restore_historical_endpoint(project,self.base)
        self.assertEqual(result["commit"],runner.HISTORICAL_ENDPOINT)
        self.assertEqual(len(result["members"]),1668)
        for path, expected in result["members"].items():
            self.assertEqual(runner.formal.file_hash(project/path),expected,path)
        self.assertNotIn("scripts/run/run_campaign_progression.gd",result["members"])
        self.assertNotIn("resources/items/forest_heart_gold.tres",result["members"])

    def test_changed_endpoint_manifest_and_missing_delta_refused(self):
        basis=Path(tempfile.mkdtemp(dir=self.home))
        shutil.copytree(self.basis,basis / "basis")
        basis=basis / "basis"
        manifest=runner.read(basis/"manifest.json")
        manifest["commit"]="5d03bd1"
        (basis/"manifest.json").write_text(json.dumps(manifest))
        with self.assertRaisesRegex(ValueError,"manifest fingerprint"):
            runner.restore_historical_endpoint(self.seed,self.base,basis)
        shutil.copy2(self.basis/"manifest.json",basis/"manifest.json")
        (basis/"delta.tar.gz").write_bytes(b"not an audited archive")
        with self.assertRaisesRegex(ValueError,"delta fingerprint"):
            runner.restore_historical_endpoint(self.seed,self.base,basis)

    def test_wrong_base_and_incomplete_base_refused(self):
        changed=copy.deepcopy(self.base);changed["commit"]="unreviewed"
        with self.assertRaisesRegex(ValueError,"base identity"):
            runner.restore_historical_endpoint(self.seed,changed)
        project=self.candidate()
        (project/"scripts/player/player_motor.gd").unlink()
        with self.assertRaisesRegex(ValueError,"complete endpoint inventory"):
            runner.restore_historical_endpoint(project,self.base)

    def test_missing_current_shared_asset_is_not_borrowed_or_synthesized(self):
        project=self.candidate()
        with patch.object(runner,"ROOT",self.home / "empty_shallow_checkout"):
            with self.assertRaisesRegex(ValueError,"historical shared asset differs"):
                runner.restore_historical_endpoint(project,self.base,self.basis)

    def test_current_policy_contract_requires_both_forest_core_members(self):
        sources=runner.formal.source_files()
        basis={"schema_version":1,"encounter_policy":"kill_from_bank_v1",
               "reward_policy":"two_actual_medium_and_camp_v1",
               "driver_sources":{"res://"+p:sources[p] for p in runner.formal.driver_source_paths()},
               "core_invariants":{"res://"+p:sources[p] for p in runner.formal.core_source_paths()}}
        data={"capture_contract_version":3,"encounter_policy":"kill_from_bank_v1","policy_basis":basis,
              "capture_source_hashes":{p:"0"*64 for p in ["res://tools/level_formal_capture.gd","res://tests/level_formal_trace.gd","res://scripts/art/plains_region_scenery.gd"]},
              "runtime_source_hashes":{"res://"+p:h for p,h in sources.items() if p=="project.godot" or p.startswith(("scripts/","scenes/","resources/","config/","shaders/","assets/"))},
              "resource_receipts":[],"policy_observations":[]}
        self.assertEqual(runner.formal.validate_policy_basis(data,sources),[])
        for name in ["scripts/run/run_campaign_progression.gd","resources/items/forest_heart_gold.tres"]:
            with self.subTest(path=name):
                bad=copy.deepcopy(data);del bad["policy_basis"]["core_invariants"]["res://"+name]
                self.assertIn("missing/changed actual source basis/core_invariants",runner.formal.validate_policy_basis(bad,sources))


class DeadLowEntranceTests(unittest.TestCase):
    def setUp(self):
        self.row={"guard_id":"plains/enemy/entry","manifest":{"connections":[
            {"kind":"challenge","a":"entry","b":"deep_region_top"},
            {"kind":"horizontal","a":"previous","b":"entry","modules":[0]}],
            "nodes":[{"id":"incoming/module"}],"enemies":[{"id":"plains/enemy/entry","area":"entry"}]},
            "state":{"entry_tick":100,"entry_guard":[{"id":"plains/enemy/entry","terminal":True,"health":0}]},
            "events":[{"kind":"shot_accepted","event_id":"shot:real","tick":90},
                {"kind":"damage_committed","target":"plains/enemy/entry","event_id":"shot:real","tick":95,
                 "source":"player_projectile:real","lethal":True,"health_after":0}]}

    def test_manifest_bound_projectile_lethal_before_entry(self):
        self.assertTrue(runner.validate_dead_low_guard(self.row))

    def test_wrong_and_empty_identity_rejected(self):
        for value in ["", "unrelated/dead_enemy"]:
            with self.subTest(identity=value):
                bad=copy.deepcopy(self.row);bad["guard_id"]=value
                with self.assertRaises(ValueError):runner.validate_dead_low_guard(bad)

    def test_missing_and_ambiguous_manifest_actor_rejected(self):
        for enemies in [[],self.row["manifest"]["enemies"]*2]:
            bad=copy.deepcopy(self.row);bad["manifest"]["enemies"]=enemies
            with self.assertRaises(ValueError):runner.validate_dead_low_guard(bad)

    def test_empty_live_or_wrong_entry_observation_rejected(self):
        for guards in [[],[{"id":"plains/enemy/entry","health":1,"terminal":False}],
                       [{"id":"unrelated/dead_enemy","health":0,"terminal":True}]]:
            bad=copy.deepcopy(self.row);bad["state"]["entry_guard"]=guards
            with self.assertRaises(ValueError):runner.validate_dead_low_guard(bad)

    def test_missing_real_shot_and_foreign_lethal_rejected(self):
        for change in ["missing_shot","foreign_lethal","direct_damage"]:
            bad=copy.deepcopy(self.row)
            if change=="missing_shot":bad["events"].pop(0)
            elif change=="foreign_lethal":bad["events"][1]["target"]="unrelated/dead_enemy"
            else:bad["events"][1]["source"]="direct_fixture"
            with self.assertRaises(ValueError):runner.validate_dead_low_guard(bad)

    def test_late_lethal_and_shot_after_hit_rejected(self):
        for field in ["late_hit","late_shot"]:
            bad=copy.deepcopy(self.row);bad["events"][1 if field=="late_hit" else 0]["tick"]=101
            with self.assertRaises(ValueError):runner.validate_dead_low_guard(bad)


class ActualMapIdentityTests(unittest.TestCase):
    def test_actual_second_map_seed_difficulty_and_stage_required(self):
        row={"map_index":2,"root_seed":"fixture","actual_stage_identity":{"map_index":2,"manifest_seed":"fixture/plains/map_2","manifest_difficulty":"advanced","region":"plains"},"manifest":{"seed":"fixture/plains/map_2","difficulty":"advanced","region":"plains"}}
        self.assertTrue(runner.validate_reward_map_identity(row))
        for change in ["stage","seed","difficulty","manifest","absent"]:
            bad=copy.deepcopy(row)
            if change=="stage":bad["actual_stage_identity"]["map_index"]=1
            elif change=="seed":bad["actual_stage_identity"]["manifest_seed"]="fixture"
            elif change=="difficulty":bad["actual_stage_identity"]["manifest_difficulty"]="intro"
            elif change=="manifest":bad["manifest"]["seed"]="fixture"
            else:bad.pop("actual_stage_identity")
            with self.subTest(change=change),self.assertRaises(ValueError):runner.validate_reward_map_identity(bad)


if __name__ == "__main__":
    unittest.main()
