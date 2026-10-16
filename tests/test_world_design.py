"""Counterexamples for design counts without opening unimplemented regions."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from check_world_design import validate


class WorldAuthorityTests(unittest.TestCase):
    def setUp(self):
        self.world = json.loads((ROOT / "docs/world_regions.json").read_text())
        self.contract = json.loads((ROOT / "docs/design_contract.json").read_text())

    def check(self, world=None, contract=None):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)
            (path / "world.json").write_text(json.dumps(self.world if world is None else world))
            (path / "contract.json").write_text(json.dumps(self.contract if contract is None else contract))
            return validate(path / "world.json", path / "contract.json")

    def test_six_stages_sixteen_pool_and_plains_only_pass(self):
        self.assertEqual(self.check(), [])

    def test_old_six_total_pool_rejected_even_when_both_files_agree(self):
        self.world["region_pool_count"] = 6
        self.contract["world_design"]["region_pool_count"] = 6
        self.assertTrue(any("sixteen" in error for error in self.check()))

    def test_actual_registry_count_cannot_be_replaced_by_a_label(self):
        self.world["regions"].pop()
        self.assertTrue(any("sixteen" in error for error in self.check()))

    def test_sixteen_sequential_stages_rejected(self):
        self.world["regions_per_run"] = 16
        self.contract["formal_run"]["regions_per_run"] = 16
        self.contract["world_design"]["stage_count"] = 16
        self.assertTrue(any("six stages" in error for error in self.check()))

    def test_future_formal_region_and_catalog_runtime_promotion_rejected(self):
        self.contract["formal_run"].pop("runtime_contract_version", None)
        self.contract["formal_run"]["implemented_regions"] = ["plains", "thorn_forest"]
        self.assertTrue(any("Only plains" in error for error in self.check()))
        self.contract["formal_run"]["implemented_regions"] = ["plains"]
        self.world["regions"][1]["runtime_available"] = True
        self.assertTrue(any("runtime-available" in error for error in self.check()))

    def test_two_region_runtime_rejects_unimplemented_third_region(self):
        self.assertEqual(self.check(), [])
        self.contract["formal_run"]["implemented_regions"].append("windswept_canyon")
        self.assertTrue(any("current runtime" in error for error in self.check()))

    def test_unknown_runtime_contract_version_is_rejected(self):
        self.contract["formal_run"]["runtime_contract_version"] = 999
        self.assertTrue(any("runtime consumer" in error for error in self.check()))

    def test_old_ambiguous_fields_and_erased_history_rejected(self):
        self.contract["formal_run"]["biome_count"] = 6
        self.assertTrue(any("Ambiguous" in error for error in self.check()))
        del self.contract["formal_run"]["biome_count"]
        self.world["legacy_total_region_plan"] = {}
        self.assertTrue(any("historical" in error for error in self.check()))

    def test_tampered_authority_or_matrix_stage_rejected(self):
        original = copy.deepcopy(self.world)
        self.world["framework_authority"]["sha256"] = "0" * 64
        self.contract["world_design"]["authority"]["sha256"] = "0" * 64
        self.assertTrue(any("hash changed" in error for error in self.check()))
        self.world = original
        self.contract["world_design"]["authority"] = copy.deepcopy(original["framework_authority"])
        self.world["regions"][1]["layer"] = 3
        self.assertTrue(any("authority matrix" in error for error in self.check()))

    def test_candidate_edges_and_imported_handoff_protections_remain(self):
        self.world["regions"][0]["next_region_ids"].append("world_clockheart")
        errors = self.check()
        self.assertTrue(any("skip layers" in error for error in errors))
        self.assertTrue(any("original proposal" in error for error in errors))
        self.world["source"]["sha256"] = "0" * 64
        self.assertTrue(any("handoff hash" in error for error in self.check()))


if __name__ == "__main__":
    unittest.main()
