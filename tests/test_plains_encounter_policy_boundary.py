"""Bounded migration guard unit cases; native evidence remains the runner's job."""
import copy
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


if __name__ == "__main__":
    unittest.main()
