"""Authority extraction tests: the document remains the single design source."""
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from level_region_context import ContextError, REGIONS, WORLD, build_region_context, parse_gate, resolve_region_id, region_registry


class RegionContextTests(unittest.TestCase):
    def test_request_resolution_is_derived_and_never_defaults_unknown_to_plains(self):
        self.assertEqual(resolve_region_id("优化风铃平原"), "windchime_plains")
        self.assertEqual(resolve_region_id("制作荆棘森林"), "thorn_forest")
        self.assertEqual(resolve_region_id("制作森林"), "thorn_forest")
        self.assertEqual(resolve_region_id("create glacier"), "frostmirror_glacier")
        self.assertEqual(resolve_region_id("optimize forest"), "thorn_forest")
        self.assertIsNone(resolve_region_id("未知地下河"))
        self.assertIsNone(resolve_region_id("deforestation"))
        self.assertEqual(len(region_registry()), 16)
        with self.assertRaisesRegex(ContextError, "Ambiguous"):
            resolve_region_id("比较森林与平原")

    def test_all_catalog_regions_resolve_with_cited_inputs(self):
        rows = json.loads((ROOT / WORLD).read_text())["regions"]
        self.assertEqual(len(rows), 16, "Current reviewed design has sixteen regions")
        stages = set()
        for row in rows:
            context = build_region_context(row["id"])
            stages.add(context["design"]["stage"]["value"])
            self.assertEqual(context["name"], row["working_name"])
            self.assertTrue(context["design"]["learning"])
            self.assertTrue(context["design"]["art"]["material_and_light"])
            for source in context["sources"]:
                raw = (ROOT / source["path"]).read_bytes()
                self.assertEqual(source["sha256"], hashlib.sha256(raw).hexdigest())
                self.assertGreaterEqual(source["line_start"], 1)
                self.assertLessEqual(source["line_end"], len(raw.decode().splitlines()))
        self.assertEqual(stages, {"S1", "S2", "S3", "S4", "S5", "S6"})

    def test_forest_has_only_hook_gate_and_separate_runtime_scope(self):
        context = build_region_context("荆棘森林")
        self.assertEqual(context["region_id"], "thorn_forest")
        self.assertEqual(context["design"]["gate"]["alternatives"], [["H"]])
        self.assertIn("不得出现 W/D/U1/U2", context["design"]["optional_gate"]["text"])
        self.assertEqual(context["implementation"]["formal_region"], "consumer_present_in_source")
        self.assertIsNone(context["implementation"]["runtime_available"])
        hook = context["implementation"]["abilities"]["H"]
        self.assertEqual(hook["status"], "grant_handler_present")
        self.assertTrue(hook["studio_grant_call_present"])
        self.assertEqual(hook["formal_grant"], "not_inferred")
        self.assertEqual(context["capability_ids"]["values"]["H"], "grapple")

    def test_latest_overrides_and_candidate_status_are_preserved(self):
        context = build_region_context("thorn_forest")
        override_text = "\n".join(item["text"] for item in context["overrides"])
        self.assertIn("360°", override_text)
        self.assertIn("同一时刻", override_text)
        self.assertTrue(any("action_budget_spec.md" in s["path"] for s in context["sources"]))
        self.assertTrue(context["design"]["gate"]["status"].startswith("PROPOSED"))
        self.assertEqual(context["locked_principles"][0]["status"], "LOCKED")
        self.assertTrue(all(item["status"] == "PROPOSED" for item in context["design"]["learning"]))

    def test_real_single_weapon_inventory_and_lv3_candidates(self):
        context = build_region_context("firefly_marsh")
        weapons = context["weapon_context"]["source_inventory"]
        self.assertEqual([sum(w["tier"] == tier for w in weapons) for tier in [1, 2, 3]], [3, 6, 6])
        self.assertEqual(len({w["branch"] for w in weapons if w["tier"] == 2}), 6)
        self.assertIn("one_current_weapon", context["weapon_context"]["selection"])
        self.assertEqual(context["weapon_context"]["rules"][2]["status"], "OPEN")
        self.assertIn("尚未定稿", context["weapon_context"]["rules"][1]["text"])

    def test_old_world_runtime_flag_does_not_disable_formal_plains(self):
        context = build_region_context("windchime_plains")
        self.assertFalse(context["implementation"]["catalog_runtime_available"])
        self.assertFalse(context["implementation"]["catalog_flag_is_authoritative"])
        self.assertEqual(context["implementation"]["formal_region"], "consumer_present_in_source")
        self.assertEqual(context["implementation"]["validation_status"], "unverified")

    def test_alternative_locks_are_parsed_without_asserting_reachability(self):
        self.assertEqual(build_region_context("frostmirror_glacier")["design"]["gate"]["alternatives"], [["W"], ["D"]])
        self.assertEqual(build_region_context("shattered_isles")["design"]["gate"]["alternatives"], [["H", "W"], ["H", "D"], ["W", "D"]])
        self.assertEqual(build_region_context("root_sanctuary")["design"]["gate"]["alternatives"], [["H", "W", "U1"]])
        for invalid in ["H OR teleport", "H+H", "W/H/W", "H+W/W+H", "", "H+(W/D)"]:
            with self.assertRaises(ContextError):
                parse_gate(invalid)

    def fixture(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        for source in build_region_context("thorn_forest")["sources"]:
            target = root / source["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / source["path"], target)
        style_path = json.loads((ROOT/'docs/creative_direction/bibles/registry.json').read_bytes())['shared_style_authority']['path']
        supplement = json.loads((ROOT/style_path).read_bytes())
        for name in [style_path, *[row['path'] for row in supplement['runtime_reference']['references']]]:
            target = root/name; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(ROOT/name,target)
        return root

    def test_document_edits_flow_through_instead_of_a_copied_table(self):
        root = self.fixture()
        path = root / REGIONS
        path.write_text(path.read_text().replace("活锚点、牵引踢跳、高速树冠穿越", "测试用已修改身份"))
        context = build_region_context("thorn_forest", root)
        self.assertEqual(context["design"]["identity"]["text"], "测试用已修改身份")
        self.assertEqual(context["design"]["identity"]["source"]["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())

    def test_conflicting_or_unknown_authorities_fail_closed(self):
        with self.assertRaises(ContextError):
            build_region_context("invented_region")
        root = self.fixture()
        path = root / WORLD
        catalog = json.loads(path.read_text())
        next(row for row in catalog["regions"] if row["id"] == "thorn_forest")["layer"] = 5
        path.write_text(json.dumps(catalog, ensure_ascii=False))
        with self.assertRaisesRegex(ContextError, "Stage conflict"):
            build_region_context("thorn_forest", root)

    def test_unrecognized_gate_does_not_silently_fall_back_to_plains(self):
        root = self.fixture()
        path = root / REGIONS
        path.write_text(path.read_text().replace("| S2 | 荆棘森林 | **H** |", "| S2 | 荆棘森林 | TELEPORT |"))
        with self.assertRaisesRegex(ContextError, "Unsupported"):
            build_region_context("thorn_forest", root)


if __name__ == "__main__":
    unittest.main()
