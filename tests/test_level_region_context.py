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
from level_region_context import ContextError, REGIONS, WORLD, build_region_context, parse_gate, resolve_region_id, region_registry, region_write_scope


class RegionContextTests(unittest.TestCase):
    def test_migrated_regional_scopes_keep_ownership_and_unknown_shared_refusal(self):
        for paths, expected in [
            (["game/world/generation/thorn_forest_new.gd"], ["thorn_forest"]),
            (["experiments/generation/forest_new.gd"], ["thorn_forest"]),
            (["game/presentation/world/plains_surface.gd"], ["windchime_plains"]),
        ]:
            with self.subTest(paths=paths):
                self.assertEqual(region_write_scope(paths), {"region_ids": expected, "unresolved_production_paths": []})
        unknown = ["game/world/generation/new_region.gd", "game/application/demo_app.gd",
                   "experiments/terrain/entries/new_study.tscn", "experiments/motion/action_studio.gd"]
        self.assertEqual(region_write_scope(unknown), {"region_ids": [], "unresolved_production_paths": unknown})
        shared = ["game/player/player_motor.gd", "game/platform/persistence/save_store.gd",
                  "game/loadout/inventory/run_inventory.gd", "experiments/audio/neutral_signal.gd"]
        self.assertEqual(region_write_scope(shared), {"region_ids": [], "unresolved_production_paths": []})
        with tempfile.TemporaryDirectory() as folder:
            missing_catalog = Path(folder)
            self.assertEqual(region_write_scope(["game/world/generation/new_region.gd"], missing_catalog)["unresolved_production_paths"],
                             ["game/world/generation/new_region.gd"])
            self.assertEqual(region_write_scope(["game/presentation/actors/shared.gd"], missing_catalog)["unresolved_production_paths"], [])

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


# Finite source-chain negatives; no runtime or region authorization.
from level_region_context import Source, _forest_consumer_observed

APP = 'game/application/demo_app.gd'
PROVIDER = 'game/world/levels/providers/forest_level_provider.gd'
ADAPTER = 'game/world/levels/providers/legacy_region_plan_adapter.gd'
CONFIGURED = 'game/world/levels/providers/generated_demo_stage.gd'
STAGE = 'game/world/levels/providers/thorn_forest_region_stage.gd'
INHERITED = 'game/world/levels/providers/plains_region_stage.gd'
RUNTIME = 'game/world/levels/level_runtime.gd'
ASSEMBLER = 'game/world/generation/thorn_forest_region_assembler.gd'
GENERATOR = 'game/world/generation/thorn_forest_region_generator.gd'


class ForestConsumerEdgeTests(unittest.TestCase):
    def fixture(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        observed, references = _forest_consumer_observed(ROOT, Source(ROOT, APP))
        self.assertTrue(observed)
        for name in [APP, *[ref['path'] for ref in references]]:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, path)
        return root

    def test_each_real_chain_edge_is_required(self):
        mutations = [
            (APP, 'var request := LevelRequest.new()', 'var request := WrongRequest.new()'),
            (APP, 'request.region_id=active_region_id', 'request.region_id=&"plains"'),
            (APP, 'ForestLevelProvider.load_level(request)', 'PlainsLevelProvider.load_level(request)'),
            (APP, 'ThornForestRegionStage.new()', 'PlainsRegionStage.new()'),
            (APP, 'configure_level(loaded.plan,loaded.legacy_generated,controller.motor.tuning)', 'configure_generated(loaded.legacy_generated,controller.motor.tuning)'),
            (APP, 'func _select_next_region(', 'func _unused_select_next_region('),
            (APP, 'func start_debug_region(', 'func unused_start_debug_region('),
            (PROVIDER, 'ThornForestRegionGenerator.new().generate(', 'PlainsRegionGenerator.new().generate('),
            (PROVIDER, 'LegacyRegionPlanAdapter.generated(generated,request.tuning,request.map_index,true)', 'LegacyRegionPlanAdapter.generated(generated,request.tuning,request.map_index,false)'),
            (ADAPTER, 'var result := geometry(data.manifest,tuning,forest_region)', 'var result := LevelBuildResult.new()'),
            (ADAPTER, 'plan.forest=forest', 'plan.forest=null'),
            (ADAPTER, 'result.plan=plan', 'result.plan=null'),
            (CONFIGURED, 'level_plan=plan', 'level_plan=null'),
            (STAGE, 'LevelRuntime.assemble(self,level_plan,region_state,generated.manifest)', 'OtherRuntime.assemble(self,level_plan,region_state,generated.manifest)'),
            (STAGE, 'extends PlainsRegionStage', 'extends DemoStage'),
            (INHERITED, 'extends GeneratedDemoStage', 'extends DemoStage'),
            (RUNTIME, 'ThornForestRegionAssembler.new() if plan.forest!=null', 'PlainsRegionAssembler.new() if plan.forest!=null'),
            (RUNTIME, 'parent.add_child(assembler)', 'pass'),
            (RUNTIME, 'assembler.build_plan(plan,presentation)', 'assembler.build({},null)'),
            (ASSEMBLER, 'forest_geometry=plan.forest', 'forest_geometry=null'),
            (GENERATOR, 'return generate_version(str(capability_snapshot.get("forest_content_version",VERSION)),seed_value,tuning,map_index,capability_snapshot)', 'return {}'),
        ]
        root = self.fixture()
        for name, old, new in mutations:
            with self.subTest(path=name, removed=old):
                path = root / name
                original = path.read_text()
                self.assertIn(old, original)
                try:
                    path.write_text(original.replace(old, new))
                    self.assertFalse(_forest_consumer_observed(root, Source(root, APP))[0])
                finally:
                    path.write_text(original)

    def test_comments_strings_and_other_function_do_not_supply_missing_call(self):
        root = self.fixture()
        path = root / STAGE
        original = path.read_text()
        statement = 'var built := LevelRuntime.assemble(self,level_plan,region_state,generated.manifest)'
        for replacement in ['# ' + statement, 'var example = "' + statement + '"',
                            'var example = """\n' + statement + '\n\t"""']:
            with self.subTest(replacement=replacement):
                path.write_text(original.replace(statement, replacement))
                self.assertFalse(_forest_consumer_observed(root, Source(root, APP))[0])
        path.write_text(original.replace(statement, 'var built := {}') + '\nfunc unused_example():\n\t' + statement + '\n')
        self.assertFalse(_forest_consumer_observed(root, Source(root, APP))[0])

    def test_top_level_multiline_strings_cannot_forge_consumer_edges(self):
        root = self.fixture()
        statement = 'var built := LevelRuntime.assemble(self,level_plan,region_state,generated.manifest)'
        cases = [
            (STAGE, 'func _ready(', 'func _unused_ready(', 'func _ready() -> void:\n\t' + statement),
            (STAGE, 'extends PlainsRegionStage', 'extends DemoStage', 'extends PlainsRegionStage'),
            (INHERITED, 'extends GeneratedDemoStage', 'extends DemoStage', 'extends GeneratedDemoStage'),
        ]
        for name, old, new, fake_edge in cases:
            path = root / name
            original = path.read_text()
            self.assertIn(old, original)
            for quote in ['"""', "'''", '"', "'"]:
                with self.subTest(path=name, fake=fake_edge, quote=quote):
                    if len(quote) == 3:
                        fake = 'const EXAMPLE = ' + quote + '\n' + fake_edge + '\n' + quote + '\n'
                    else:
                        # Godot accepts backslash-newline inside ordinary strings.
                        fake = 'const EXAMPLE = ' + quote + 'example\\\n' + fake_edge.replace('\n', '\\\n') + '\\\n' + quote + '\n'
                    try:
                        path.write_text(original.replace(old, new) + '\n' + fake)
                        self.assertFalse(_forest_consumer_observed(root, Source(root, APP))[0])
                    finally:
                        path.write_text(original)

    def test_source_quote_examples_in_comments_are_not_string_context(self):
        root = self.fixture()
        path = root / STAGE
        original = path.read_text()
        examples = ['# Example triple quote: """', "# Example triple quote: '''",
                    '# Example continuation: \\', 'const EXAMPLE = "# is inside a string"',
                    'const ESCAPED_EXAMPLE = "escaped quote: \\" and hash #"']
        path.write_text(original + '\n' + '\n'.join(examples) + '\n')
        self.assertTrue(_forest_consumer_observed(root, Source(root, APP))[0])

    def test_order_and_missing_source_fail_closed(self):
        root = self.fixture()
        path = root / RUNTIME
        original = path.read_text()
        before = '\tparent.add_child(assembler)\n\tvar result := assembler.build_plan(plan,presentation)'
        self.assertIn(before, original)
        path.write_text(original.replace(before, '\tvar result := assembler.build_plan(plan,presentation)\n\tparent.add_child(assembler)'))
        self.assertFalse(_forest_consumer_observed(root, Source(root, APP))[0])
        path.unlink()
        with self.assertRaises(FileNotFoundError):
            _forest_consumer_observed(root, Source(root, APP))

    def test_chain_sources_are_cited_without_claiming_runtime_or_grants(self):
        context = build_region_context('thorn_forest')
        implementation = context['implementation']
        self.assertEqual(implementation['formal_region'], 'consumer_present_in_source')
        self.assertIsNone(implementation['runtime_available'])
        self.assertEqual(implementation['validation_status'], 'unverified')
        self.assertFalse(implementation['catalog_flag_is_authoritative'])
        expected = {APP, PROVIDER, ADAPTER, CONFIGURED, STAGE, INHERITED, RUNTIME, ASSEMBLER, GENERATOR}
        refs = {ref['path']: ref for ref in implementation['formal_consumer_sources']}
        self.assertTrue(expected.issubset(refs))
        for name in expected:
            self.assertEqual(refs[name]['sha256'], hashlib.sha256((ROOT / name).read_bytes()).hexdigest())
        import level_design
        mission = level_design.route_request('制作荆棘森林')
        self.assertFalse(mission['preparation']['production_boundary']['formal_opening_authorized'])


if __name__ == "__main__":
    unittest.main()
