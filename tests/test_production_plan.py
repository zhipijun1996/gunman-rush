"""Impact routing counterexamples against the real existing check inventory."""
import copy
import contextlib
import hashlib
import io
import types
from unittest.mock import patch
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import production_plan
from production_plan import make_plan, run_commands, validate_policy


class ProductionPlanTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.policy = json.loads((ROOT / "config/production_impact.json").read_text())
        cls.manifest = json.loads((ROOT / "tools/harness/profiles.json").read_text())

    def plan(self, paths, stage="development", policy=None):
        return make_plan(paths, stage, policy or self.policy, self.manifest)

    def test_docs_do_not_export_or_claim_test_execution(self):
        plan = self.plan(["docs/handoff.md", "AGENTS.md"])
        self.assertEqual(set(plan["checks"]), set(self.manifest["profiles"]["docs"]))
        self.assertNotIn("web-build", plan["checks"])
        self.assertEqual(plan["status"], "planned")
        self.assertEqual(plan["approval_scope"], "plan_only")
        self.assertNotIn("passed", json.dumps(plan))

    def test_shared_player_has_short_feedback_then_full_integration(self):
        paths = ["game/presentation/actors/art/avatar_presentation.gd"]
        development = self.plan(paths)
        self.assertIn("underworld-player-animation", development["checks"])
        self.assertIn("actor-actions", development["checks"])
        self.assertNotIn("web-build", development["checks"])
        integration = self.plan(paths, "integration")
        self.assertEqual(integration["selection"], "full")
        self.assertTrue(set(self.manifest["profiles"]["full"]).issubset(integration["checks"]))
        self.assertTrue(integration["escalations"])
        self.assertIn("--release", integration["commands"][0])

    def test_same_extension_does_not_grant_unknown_source_narrow_scope(self):
        plan = self.plan(["scripts/art/new_global_controller.gd"])
        self.assertEqual(plan["selection"], "full")
        self.assertEqual(plan["escalations"][0]["path"], "scripts/art/new_global_controller.gd")

    def test_formal_player_body_retains_style_binding_and_full_integration(self):
        for path in ("game/presentation/actors/underworld_plains/underworld_player.gd",
                     "assets/characters/courier/courier_visual.gd"):
            with self.subTest(path=path):
                development = self.plan([path])
                self.assertEqual(development["selection"], "affected_checks")
                self.assertIn("underworld-player-animation", development["checks"])
                self.assertIn("region-bible-contract", development["checks"])
                self.assertEqual(self.plan([path], "integration")["selection"], "full")

    def test_formal_enemy_mapping_does_not_admit_unreviewed_components(self):
        path = "game/presentation/actors/underworld_plains/underworld_enemy.gd"
        self.assertIn("underworld-damage-feedback", self.plan([path])["checks"])
        self.assertEqual(self.plan([path])["selection"], "affected_checks")
        self.assertEqual(self.plan([path], "integration")["selection"], "full")
        self.assertEqual(self.plan(["scripts/underworld_plains/new_enemy.gd"])["selection"], "full")

    def test_physics_rng_save_config_and_scene_cannot_hide_in_docs_changes(self):
        for path in ("config/player_tuning.json", "config/input_profile.json", "game/player/player_motor.gd", "scripts/generation/new_rng.gd", "scripts/save/new_save.gd", "scenes/player.tscn", "resources/foo.tres", "project.godot", ".github/workflows/new.yml"):
            with self.subTest(path=path):
                plan = self.plan(["docs/handoff.md", path])
                self.assertEqual(plan["selection"], "full")
                self.assertIn(path, [item["path"] for item in plan["escalations"]])

    def test_deleted_or_renamed_old_path_remains_a_real_impact(self):
        # changed_paths reports names for deleted files too; existence is not a
        # reason to discard old consumers or downgrade a removed runtime file.
        plan = self.plan(["scripts/retired_damageable.gd", "docs/removal.md"])
        self.assertIn("scripts/retired_damageable.gd", plan["changed_paths"])
        self.assertEqual(plan["selection"], "full")

    def test_web_dependency_closure_exports_only_at_integration(self):
        path = ["tools/web/boot.js"]
        development = self.plan(path)
        self.assertIn("web-cache", development["checks"])
        self.assertIn("web-resource-contract-tests", development["checks"])
        self.assertNotIn("web-build", development["checks"])
        integration = self.plan(path, "integration")
        self.assertIn("web-build", integration["checks"])
        self.assertIn("web-bundle", integration["checks"])
        self.assertEqual(integration["domains"], ["web_contracts", "web"])
        self.assertNotIn("forest-depth-region", integration["checks"])

    def test_overlapping_changes_run_each_check_once(self):
        plan = self.plan(["AGENTS.md", "docs/handoff.md", "tools/web/boot.js", "tools/test_web_cache_policy.mjs", "tools/web/boot.js"])
        self.assertEqual(len(plan["checks"]), len(set(plan["checks"])))
        command = plan["commands"][0]
        self.assertEqual(command.count("--check"), len(plan["checks"]))

    def test_new_harness_check_or_policy_typo_is_not_silently_skipped(self):
        policy = copy.deepcopy(self.policy)
        policy["domains"]["movie"]["development"].append("missing-real-check")
        with self.assertRaisesRegex(ValueError, "Unknown Harness check"):
            self.plan(["tools/capture_actions.py"], policy=policy)

    def test_dependency_cycle_and_missing_consumer_fail_before_execution(self):
        policy = copy.deepcopy(self.policy)
        policy["domains"]["web_contracts"]["depends_on"] = ["web"]
        with self.assertRaisesRegex(ValueError, "cycle"):
            validate_policy(policy, self.manifest)
        policy = copy.deepcopy(self.policy)
        policy["domains"]["web"]["depends_on"] = ["unknown-consumer"]
        with self.assertRaisesRegex(ValueError, "Unknown dependency"):
            validate_policy(policy, self.manifest)

    def test_planner_policy_requires_own_regression_without_weakening_config_fallback(self):
        plan = self.plan(["config/production_impact.json"])
        self.assertIn("harness-tests", plan["checks"])
        self.assertEqual(plan["additional_commands"], [["python3", "tests/test_production_plan.py"]])
        self.assertEqual(self.plan(["config/unregistered_visual_config.json"])["selection"], "full")

    def test_offline_content_changes_only_select_pure_content_check(self):
        for stage in ("development", "integration"):
            plan = self.plan(["tools/level_content.py", "tools/level_content_contract.py"], stage)
            self.assertEqual(plan["selection"], "affected_checks")
            self.assertIn("ai-level-content", plan["checks"])
            self.assertNotIn("ai-level-pilot", plan["checks"])
            self.assertNotIn("web-build", plan["checks"])

    def test_isolated_pilot_catalogue_has_exact_consumer_and_dependency_closure(self):
        for stage in ("development", "integration"):
            plan = self.plan(["config/level_pilot_candidates.json"], stage)
            self.assertEqual(plan["selection"], "affected_checks")
            self.assertEqual(plan["domains"], ["ai_level_content", "ai_level_pilot"])
            self.assertIn("ai-level-content", plan["checks"])
            self.assertIn("ai-level-pilot", plan["checks"])
            self.assertNotIn("web-build", plan["checks"])

    def test_candidate_config_exception_does_not_cover_nearby_or_shared_paths(self):
        for path in ("config/level_pilot_candidates_extra.json", "config/pilot/player_tuning.json",
                     "config/player_tuning.json", "config/input_profile.json"):
            with self.subTest(path=path):
                self.assertEqual(self.plan([path])["selection"], "full")
        # A policy rule can map an existing shared path, but cannot declare its
        # own broad bypass of the audited exact experiment consumer.
        policy = copy.deepcopy(self.policy)
        rule = next(r for r in policy["rules"] if r["id"] == "ai-level-pilot")
        rule["paths"].extend(["config/*", "config/player_tuning.json"])
        rule["reviewed_exact_config"] = True
        self.assertEqual(self.plan(["config/player_tuning.json"], policy=policy)["selection"], "full")
        self.assertEqual(self.plan(["config/new_shared.json"], policy=policy)["selection"], "full")

    def test_exact_pilot_path_without_reviewed_rule_identity_fails_closed(self):
        for field, value in (("id", "wrong-experiment"), ("domain", "process")):
            policy = copy.deepcopy(self.policy)
            rule = next(r for r in policy["rules"] if r["id"] == "ai-level-pilot")
            rule[field] = value
            self.assertEqual(self.plan(["config/level_pilot_candidates.json"], policy=policy)["selection"], "full")

    def test_shared_runtime_change_with_pilot_catalogue_escalates_full(self):
        paths = ["config/level_pilot_candidates.json", "game/world/components/platforming_module.gd"]
        self.assertEqual(self.plan(paths)["selection"], "full")
        self.assertTrue(set(self.manifest["profiles"]["full"]).issubset(self.plan(paths)["checks"]))

    def test_new_checks_keep_release_profiles_and_use_unique_bounded_pilot_output(self):
        for profile in ("core", "gameplay", "full"):
            self.assertIn("ai-level-content", self.manifest["profiles"][profile])
            self.assertIn("ai-level-pilot", self.manifest["profiles"][profile])
        pilot = self.manifest["checks"]["ai-level-pilot"]
        self.assertTrue(pilot["serial"])
        self.assertIn("build/verification/ai-level-pilot/{check_token}", pilot["argv"])
        self.assertLessEqual(pilot["timeout_seconds"], 960)
        self.assertEqual(self.plan(["config/level_pilot_candidates.json"], "release")["selection"],
                         "original_release_delivery")

    def test_release_names_original_delivery_and_does_not_certify_full_profile(self):
        plan = self.plan(["docs/handoff.md"], "release")
        self.assertEqual(plan["commands"], [["python3", "tools/deliver.py", "--jobs", "1"]])
        self.assertEqual(plan["checks"], [])
        self.assertEqual(plan["selection"], "original_release_delivery")
        self.assertEqual(plan["device_acceptance"], "unverified")
        self.assertEqual(plan["player_acceptance"], "unverified")
        self.assertTrue(plan["release_follow_up"])

    def test_paths_cannot_escape_worktree(self):
        for path in ("../config/player_tuning.json", "/etc/passwd", "scripts/../docs/hidden.gd", "scripts\\hidden.gd", ""):
            with self.subTest(path=path), self.assertRaises(ValueError):
                self.plan([path])

    def test_actual_nonzero_process_stops_later_commands(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory) / "must-not-run"
            results = []
            code = run_commands([["python3", "-c", "raise SystemExit(17)"],
                                 ["python3", "-c", "from pathlib import Path; Path('must-not-run').touch()"]], Path(directory), results)
            self.assertEqual(code, 17)
            self.assertEqual(len(results), 1)
            self.assertEqual(results[0]["exit_code"], 17)
            self.assertFalse(marker.exists())

    def test_source_guard_rejects_actual_source_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "source.txt"
            source.write_text("frozen")
            def guard():
                if source.read_text() != "frozen":
                    raise RuntimeError("source changed")
            results = []
            with self.assertRaisesRegex(RuntimeError, "source changed"):
                run_commands([["python3", "-c", "from pathlib import Path; Path('source.txt').write_text('changed')"]], Path(directory), results, guard)
            self.assertEqual(results[0]["exit_code"], 0)
            self.assertEqual(source.read_text(), "changed")


    def test_early_boundary_is_only_selected_with_its_real_parent(self):
        docs = self.plan(["docs/handoff.md"])
        self.assertEqual(docs["precheck_commands"], [])
        full = self.plan(["game/application/demo_app.gd"], "integration")
        self.assertEqual(full["precheck_commands"], [["python3", "-S", "tests/test_plains_encounter_policy_boundary.py", "-v"]])
        self.assertIn("plains-encounter-policy", full["checks"])
        policy = copy.deepcopy(self.policy)
        policy["early_python_checks"][0]["parent_check"] = "not-a-real-check"
        with self.assertRaisesRegex(ValueError, "early Python"):
            self.plan(["docs/handoff.md"], policy=policy)

    def test_physical_lanes_require_the_exact_original_full_set(self):
        full = self.plan(["game/application/demo_app.gd"], "integration")
        self.assertEqual(full["ci_route"], "full_lanes")
        self.assertEqual(set(full["checks"]), set(self.manifest["profiles"]["full"]))
        parallel, serial = [full["ci_lane_checks"][lane] for lane in ("parallel", "serial")]
        self.assertFalse(set(parallel) & set(serial))
        self.assertEqual(set(parallel) | set(serial), set(full["checks"]))
        # AGENTS' current-Demo scope defers frozen history to legacy-compat.
        # Require precisely the independently reviewed one-for-one replacement;
        # normalize that name alone when checking the unchanged historic hashes.
        current_registry = "forest-current-registry"
        frozen_registry = "forest-depth-versions"
        for names, slot in ((self.manifest["profiles"]["full"], 74), (full["checks"], 85)):
            self.assertEqual(names.count(current_registry), 1)
            self.assertEqual(names[slot], current_registry)
            self.assertNotIn(frozen_registry, names)
        self.assertIn(frozen_registry, self.manifest["profiles"]["legacy-compat"])
        self.assertNotIn(current_registry, self.manifest["profiles"]["legacy-compat"])
        self.assertEqual(self.manifest["checks"][current_registry]["timeout_seconds"],
                         self.manifest["checks"][frozen_registry]["timeout_seconds"])
        # Preserve the exact pre-V5 inventory/order from main879b39e except for
        # that explicit scope split; new families still append to the baseline.
        original = self.manifest["profiles"]["full"][:144]
        digest = lambda names: hashlib.sha256(json.dumps(
            [frozen_registry if name == current_registry else name for name in names],
            separators=(",",":")).encode()).hexdigest()
        self.assertEqual(digest(original), "dd7ca8a04ea756fc112183fa3603a1cdcd75c4ff7677987702d659292d194bc2")
        self.assertEqual(digest(full["checks"][:144]), "392a72c601c87c22daa53f7e2786c3481026048ee93fddd1753564e40ece621e")
        additions = [
            "item-v5-data", "item-v5-catalog", "item-v5-pool",
            "item-v5-inventory", "item-v5-combat", "item-v5-actives",
            "item-v5-economy", "item-v5-defense", "item-v5-ui",
            "item-v5-formal", "item-v5-review", "item-v5-boss-time",
            "item-v5-core-effects", "item-v5-synergy-economy",
            "item-v5-pause-escape", "item-v5-random-context", "item-v5-manifest",
            "item-v5-authoring", "item-authoring-tools", "item-v5-art",
            "home-codex",
        ]
        # Retain the complete original165 inventory/order as a frozen prefix;
        # the new native contract appends without replacing either lane's set.
        self.assertEqual(self.manifest["profiles"]["full"][:165], original + additions)
        self.assertEqual(full["checks"][144:165], additions)
        self.assertEqual(digest(self.manifest["profiles"]["full"][:165]), "ac963a4c96ca823555c367dcb10f039ccf0b24c762bb7e7e4fe16df01f63a463")
        self.assertEqual(digest(full["checks"][:165]), "e88cea4aab3d566a2eaf8a4689f4a0f7011b69df67ac5f02ff028852994d9750")
        structure_additions = ["enemy-structure-native"]
        # Preserve all 166 reviewed checks, then append this real native case.
        self.assertEqual(self.manifest["profiles"]["full"][144:166], additions + structure_additions)
        self.assertEqual(full["checks"][144:166], additions + structure_additions)
        self.assertEqual(self.manifest["profiles"]["full"][165:166], structure_additions)
        self.assertEqual(full["checks"][165:166], structure_additions)
        motion_loot_additions = ["plains-motion-loot-02"]
        audio_additions = ["audio-feedback"]
        pressure_additions = ["windkeeper-pressure-01"]
        bell_additions = ["bellstrider-rework-01"]
        baseline_additions = additions + structure_additions + motion_loot_additions + audio_additions
        boss_additions = pressure_additions + bell_additions
        ai_additions = ["ai-level-content", "ai-level-pilot"]
        session_additions = ["run-session"]
        architecture_additions = ["architecture-tests"]
        native_additions = ["level-plan", "enemy-region-state", "game-architecture-effects",
                            "plains-revision-deform-equivalence", "entry-audio-lifecycle",
                            "entry-audio-lifecycle-comparison"]
        owner_additions = ["entry-audio-owners"]
        definition_additions = ["forest-v11-definition"]
        foundry_additions = ["foundry-lab", "foundry-touch", "foundry-feedback"]
        expected_additions = baseline_additions + boss_additions + ai_additions + session_additions + architecture_additions + native_additions + owner_additions + definition_additions + foundry_additions
        self.assertEqual(self.manifest["profiles"]["full"][144:170], baseline_additions + boss_additions)
        self.assertEqual(full["checks"][144:170], baseline_additions + boss_additions)
        self.assertEqual(self.manifest["profiles"]["full"][170:172], ai_additions)
        self.assertEqual(full["checks"][170:172], ai_additions)
        self.assertEqual(self.manifest["profiles"]["full"][144:168], baseline_additions)
        self.assertEqual(full["checks"][144:168], baseline_additions)
        self.assertEqual(self.manifest["profiles"]["full"][144:], expected_additions)
        self.assertEqual(full["checks"][144:], expected_additions)
        self.assertEqual(self.manifest["profiles"]["full"][166:167], motion_loot_additions)
        self.assertEqual(full["checks"][166:167], motion_loot_additions)
        self.assertEqual(self.manifest["profiles"]["full"][167:168], audio_additions)
        self.assertEqual(full["checks"][167:168], audio_additions)
        self.assertEqual(self.manifest["profiles"]["full"][168:169], pressure_additions)
        self.assertEqual(full["checks"][168:169], pressure_additions)
        pressure = self.manifest["checks"]["windkeeper-pressure-01"]
        self.assertEqual(pressure["argv"], ["python3", "tools/run_windkeeper_pressure_01_tests.py"])
        self.assertEqual(pressure["timeout_seconds"], 300)
        self.assertTrue(pressure["serial"])
        audio = self.manifest["checks"]["audio-feedback"]
        self.assertEqual(audio["argv"], ["python3", "tools/run_audio_feedback_tests.py"])
        self.assertEqual(audio["timeout_seconds"], 240)
        self.assertTrue(audio["serial"])
        added_parallel = ["item-v5-data", "item-authoring-tools"] + motion_loot_additions + bell_additions + ["ai-level-content"] + architecture_additions
        self.assertEqual(self.manifest["profiles"]["full"][169:170], bell_additions)
        self.assertEqual(full["checks"][169:170], bell_additions)
        self.assertEqual([name for name in parallel if name not in original], added_parallel)
        self.assertEqual([name for name in serial if name not in original], [name for name in expected_additions if name not in added_parallel])
        # Keep the complete reviewed168 and its92/76 split, then append both
        # actual native Boss contracts without replacing any original case.
        baseline_lanes = [[name for name in names if name not in boss_additions + ai_additions + session_additions + architecture_additions + native_additions + owner_additions + definition_additions + foundry_additions]
                          for names in (full["checks"], parallel, serial)]
        self.assertEqual(tuple(map(len, baseline_lanes)), (168,92,76))
        boss_lanes = [[name for name in names if name not in ai_additions + session_additions + architecture_additions + native_additions + owner_additions + definition_additions + foundry_additions]
                      for names in (full["checks"], parallel, serial)]
        self.assertEqual(tuple(map(len, boss_lanes)), (170,93,77))
        existing_lanes = [[name for name in names if name not in session_additions + architecture_additions + native_additions + owner_additions + definition_additions + foundry_additions]
                          for names in (full["checks"], parallel, serial)]
        self.assertEqual(tuple(map(len, existing_lanes)), (172,94,78))
        self.assertEqual(self.manifest["profiles"]["full"][172:173], session_additions)
        self.assertEqual(full["checks"][172:173], session_additions)
        session_lanes = [[name for name in names if name not in architecture_additions + native_additions + owner_additions + definition_additions + foundry_additions]
                         for names in (full["checks"], parallel, serial)]
        self.assertEqual(tuple(map(len, session_lanes)), (173,94,79))
        self.assertEqual(self.manifest["profiles"]["full"][173:174], architecture_additions)
        self.assertEqual(full["checks"][173:174], architecture_additions)
        architecture_lanes = [[name for name in names if name not in native_additions + owner_additions + definition_additions + foundry_additions]
                              for names in (full["checks"], parallel, serial)]
        self.assertEqual(tuple(map(len, architecture_lanes)), (174,95,79))
        self.assertEqual(self.manifest["profiles"]["full"][174:180], native_additions)
        self.assertEqual(full["checks"][174:180], native_additions)
        native_lanes = [[name for name in names if name not in owner_additions + definition_additions + foundry_additions]
                        for names in (full["checks"], parallel, serial)]
        self.assertEqual(tuple(map(len, native_lanes)), (180,95,85))
        self.assertEqual(self.manifest["profiles"]["full"][180:181], owner_additions)
        self.assertEqual(full["checks"][180:181], owner_additions)
        owner_lanes = [[name for name in names if name not in definition_additions + foundry_additions]
                       for names in (full["checks"], parallel, serial)]
        self.assertEqual(tuple(map(len, owner_lanes)), (181,95,86))
        self.assertEqual(self.manifest["profiles"]["full"][181:182], definition_additions)
        self.assertEqual(full["checks"][181:182], definition_additions)
        definition_lanes = [[name for name in names if name not in foundry_additions]
                            for names in (full["checks"], parallel, serial)]
        self.assertEqual(tuple(map(len, definition_lanes)), (182,95,87))
        # Exact ordered b893 full182/gameplay167 stay intact before this append.
        self.assertEqual(digest(self.manifest["profiles"]["full"][:182]), "d3897ab1d8b883144bd4adccd09e2adf3c87bed3a6173729913b024c517745bb")
        self.assertEqual(digest(self.manifest["profiles"]["gameplay"][:167]), "677c100793e3c9d80980aeaa18889929b2fcd01e5f77ae669c7511ca178e850a")
        self.assertEqual(self.manifest["profiles"]["full"][182:], foundry_additions)
        self.assertEqual(full["checks"][182:], foundry_additions)
        self.assertEqual(self.manifest["profiles"]["gameplay"][167:], foundry_additions)
        self.assertEqual((len(full["checks"]),len(parallel),len(serial)), (185,95,90))
        for name in full["checks"]:
            self.assertEqual(name in serial, bool(self.manifest["checks"][name].get("serial",False)))
        for paths, stage in [(["docs/handoff.md"], "integration"), (["tools/web/boot.js"], "integration"), (["game/application/demo_app.gd"], "development")]:
            scoped = self.plan(paths,stage)
            self.assertEqual(scoped["ci_route"], "selected_commands")
            self.assertEqual(scoped["ci_lane_checks"], {})
        manifest = copy.deepcopy(self.manifest)
        manifest["profiles"]["docs"].append("not-in-full")
        manifest["checks"]["not-in-full"] = {"argv":["python3","tests/extra.py"]}
        with_extra = make_plan(["game/application/demo_app.gd"],"integration",self.policy,manifest)
        self.assertEqual(with_extra["ci_route"],"selected_commands")

    def test_real_refactor_runners_keep_direct_strict_native_contracts(self):
        rows = [
            ("level-plan", "level_plan_runner", "LEVEL PLAN TESTS", 180, "assertions"),
            ("enemy-region-state", "enemy_region_state_runner", "ENEMY REGION STATE", 180, "checks"),
            ("game-architecture-effects", "game_architecture_effects_runner", "GAME ARCHITECTURE EFFECTS", 120, "assertions"),
            ("plains-revision-deform-equivalence", "plains_revision_deform_equivalence_runner", "PLAINS DEFORM EQUIVALENCE", 180, "assertions"),
            ("entry-audio-lifecycle", "entry_audio_lifecycle_runner", "ENTRY AUDIO LIFECYCLE", 180, "assertions"),
            ("entry-audio-lifecycle-comparison", "entry_audio_lifecycle_comparison_runner", "ENTRY AUDIO BASELINE COMPARISON", 60, "assertions"),
            ("entry-audio-owners", "entry_audio_owner_runner", "ENTRY AUDIO OWNERS", 180, "assertions"),
        ]
        import re
        import harness
        for name, stem, marker, budget, noun in rows:
            with self.subTest(check=name):
                runner = "tests/" + stem + ".gd"
                check = self.manifest["checks"][name]
                argv = ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60", "--path", ".", "--script", runner]
                if name == "entry-audio-lifecycle":
                    argv += ["--", "--studies"]
                elif name == "entry-audio-owners":
                    argv += ["--", "--auditions"]
                self.assertEqual(check["argv"], argv)
                self.assertEqual(check["timeout_seconds"], budget)
                self.assertTrue(check["serial"])
                self.assertEqual(check["success_pattern"], "^" + marker + ": [1-9][0-9]* " + noun + ", 0 failures$")
                self.assertIsNotNone(re.fullmatch(check["success_pattern"], marker + ": 1 " + noun + ", 0 failures"))
                for bad in (marker + ": 0 " + noun + ", 0 failures", marker + ": 1 " + noun + ", 1 failures", "incomplete"):
                    self.assertIsNone(re.fullmatch(check["success_pattern"], bad))
                source = (ROOT / runner).read_text()
                self.assertIn(marker + ": %", source)
                self.assertIn("quit(", source)
                self.assertIn(runner, check["inputs"])
                for root in ("game", "scripts", "scenes", "resources", "config", "assets", "shaders"):
                    self.assertIn(root, check["inputs"])
                for path in check["inputs"]:
                    self.assertTrue((ROOT / path).exists(), path)
                profiles = {"core", "gameplay", "full"}
                if name in ("plains-revision-deform-equivalence", "entry-audio-lifecycle", "entry-audio-owners"):
                    profiles.add("art")
                self.assertEqual({p for p, names in self.manifest["profiles"].items() if name in names}, profiles)
                plan = self.plan([runner], "integration")
                self.assertEqual(plan["selection"], "full")
                self.assertIn(name, plan["ci_lane_checks"]["serial"])
                path = "game/application/run_session.gd"
                self.assertNotEqual(harness.input_digest(check, [path], {}, {path: "a" * 64}),
                                    harness.input_digest(check, [path], {}, {path: "b" * 64}))
        self.assertIn("tests/fixtures/plains_revision_deform_2ce4ffa6",
                      self.manifest["checks"]["plains-revision-deform-equivalence"]["inputs"])
        self.assertIn("tests/fixtures/audio_lifecycle_2ce4ffa6",
                      self.manifest["checks"]["entry-audio-lifecycle-comparison"]["inputs"])

    def test_recorded_v11_definition_appends_existing_strict_adapter_without_replacing_forest(self):
        import run_integration_four_tests as wrapper
        name = "forest-v11-definition"
        check = self.manifest["checks"][name]
        self.assertEqual(check["argv"], ["python3", "tools/run_integration_four_tests.py", "--case", name])
        self.assertEqual(wrapper.CASES[name], ("tests/forest_v11_definition_runner.gd", r"FOREST V11 DEFINITION: [1-9]\d* assertions, 0 failures", 180))
        self.assertEqual(check["success_pattern"], "^" + wrapper.CASES[name][1] + "$")
        self.assertEqual(check["timeout_seconds"], 180)
        self.assertTrue(check["serial"])
        self.assertEqual({p for p, names in self.manifest["profiles"].items() if name in names}, {"core", "gameplay", "full"})
        self.assertEqual({p for p, names in self.manifest["profiles"].items() if "forest-depth-versions" in names}, {"legacy-compat"})
        original = self.manifest["checks"]["forest-depth-versions"]
        self.assertEqual(original["timeout_seconds"], 210)
        self.assertEqual(original["argv"], ["python3", "tools/run_forest_depth_versions.py", "--output-dir", "build/forest_depth/versions/native/harness-{check_token}"])
        for path in check["inputs"]:
            self.assertTrue((ROOT / path).exists(), path)
        for path in ("tests/fixtures/forest_recorded_layouts/v11_corpus_map1.json",
                     "tests/fixtures/forest_recorded_layouts/v11_corpus_map2.json",
                     "resources/enemies/legacy/plains_charger_v2.tres", "tools/run_tests.py"):
            self.assertIn(path, check["inputs"])
        plan = self.plan(["tests/forest_v11_definition_runner.gd"], "integration")
        self.assertIn(name, plan["ci_lane_checks"]["serial"])

    def test_recorded_definition_wrapper_keeps_clock_marker_and_shared_failure_propagation(self):
        # Simulated adapter output only; this unit never starts the engine.
        import run_integration_four_tests as wrapper
        import run_tests
        self.assertIs(wrapper.run_engine, run_tests.run_engine)
        argv = ["wrapper", "--case", "forest-v11-definition"]
        good = "FOREST V11 DEFINITION: 1 assertions, 0 failures\n"
        with patch.object(sys, "argv", argv), patch.object(wrapper, "run_engine", side_effect=["", good]) as engine:
            wrapper.main()
            self.assertEqual(engine.call_args_list[1].args,
                             (["--headless", "--audio-driver", "Dummy", "--fixed-fps", "60", "--path", ".", "--script", "tests/forest_v11_definition_runner.gd"], 180))
        for failed in ("", good.replace("1 assertions", "0 assertions"), good.replace("0 failures", "1 failures"),
                       good + "ERROR: Resumed function fixture class instance is gone\n",
                       RuntimeError("Godot leaked ObjectDB instances or live resources at exit"),
                       RuntimeError("Godot returned 1")):
            with self.subTest(output=str(failed)), patch.object(sys, "argv", argv), patch.object(wrapper, "run_engine", side_effect=["", failed]):
                with self.assertRaises(RuntimeError):
                    wrapper.main()

    def test_migrated_audio_entries_keep_real_scene_and_cache_coverage(self):
        import harness
        cases = {
            "entry-audio-owners": ["experiments/audio/entries/" + name + ".tscn" for name in
                                   ("audio_home_lab", "audio_ambience_lab", "audio_director_lab", "audio_director_lab_v2", "audio_director_reels")]
                                  + ["experiments/motion/entries/" + name + ".tscn" for name in
                                     ("motion_candidate", "landing_feel", "weapon_feel", "weapon_feel_v2", "action_studio")],
            "entry-audio-lifecycle": ["experiments/terrain/entries/" + name + ".tscn" for name in
                                      ("light_study", "pixel_light_study", "high_density_terrain_study", "authored_terrain_study")],
        }
        for name, paths in cases.items():
            check = self.manifest["checks"][name]
            source = (ROOT / check["argv"][check["argv"].index("--script") + 1]).read_text()
            self.assertNotIn('"res://scenes/dev/"', source)
            for path in paths:
                self.assertTrue((ROOT / path).is_file(), path)
                self.assertNotEqual(harness.input_digest(check, [path], {}, {path: "a" * 64}),
                                    harness.input_digest(check, [path], {}, {path: "b" * 64}), name + ":" + path)

    def test_moved_lab_sources_keep_the_original_shared_script_cache_coverage(self):
        import harness
        for name, check in self.manifest["checks"].items():
            if "scripts" not in check.get("inputs", []):
                continue
            for path in ("experiments/terrain/art_foundation/blob47_lab.gd",
                         "experiments/terrain/style_exploration/style_lab.gd"):
                self.assertTrue((ROOT / path).is_file())
                self.assertNotEqual(harness.input_digest(check, [path], {}, {path: "a" * 64}),
                                    harness.input_digest(check, [path], {}, {path: "b" * 64}), name + ":" + path)
        preview = "experiments/platform/preview_affordance.gd"
        check = self.manifest["checks"]["underworld-pipeline"]
        self.assertTrue((ROOT / preview).is_file())
        self.assertNotEqual(harness.input_digest(check, [preview], {}, {preview: "a" * 64}),
                            harness.input_digest(check, [preview], {}, {preview: "b" * 64}))

    def test_finite_bible_inputs_include_the_shared_frozen_source_adapter(self):
        import harness
        paths = ("tools/region_style_history.py",
                 "docs/creative_direction/archive/feature-layout-before-style26")
        for name in ("region-bible-contract", "region-bible-tests"):
            check = self.manifest["checks"][name]
            for path in paths:
                self.assertIn(path, check["inputs"])
                self.assertTrue((ROOT / path).exists())
                leaf = path + "/manifest.json" if (ROOT / path).is_dir() else path
                self.assertNotEqual(harness.input_digest(check, [leaf], {}, {leaf: "a" * 64}),
                                    harness.input_digest(check, [leaf], {}, {leaf: "b" * 64}))
        # Its existing all-source contract already includes both additions.
        self.assertNotIn("inputs", self.manifest["checks"]["creative-direction-tests"])

    def test_architecture_guard_has_real_narrow_harness_registration(self):
        name = "architecture-tests"
        check = self.manifest["checks"][name]
        self.assertEqual(check["argv"], ["python3", "tests/test_project_dependencies.py"])
        self.assertEqual(check["success_pattern"], "^OK$")
        self.assertEqual(check["timeout_seconds"], 60)
        self.assertFalse(check.get("serial", False))
        self.assertEqual(check["inputs"], ["tools/project_dependencies.py", "tests/test_project_dependencies.py"])
        self.assertEqual({p for p, names in self.manifest["profiles"].items() if name in names},
                         {"core", "gameplay", "full"})
        for path in check["inputs"]:
            self.assertTrue((ROOT / path).is_file())
            plan = self.plan([path], "integration")
            self.assertEqual(plan["selection"], "full")
            self.assertIn(name, plan["ci_lane_checks"]["parallel"])
            self.assertNotIn(name, plan["ci_lane_checks"]["serial"])

    def test_run_session_registers_actual_app_consumer_with_existing_strict_harness(self):
        name = "run-session"
        check = self.manifest["checks"][name]
        runner = "tests/run_session_runner.gd"
        self.assertEqual(check["argv"], ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60",
                                         "--path", ".", "--script", runner])
        self.assertEqual(check["success_pattern"], "^RUN SESSION TESTS: [1-9][0-9]* assertions, 0 failures$")
        self.assertEqual(check["timeout_seconds"], 180)
        self.assertTrue(check["serial"])
        self.assertTrue((ROOT / runner).is_file())
        self.assertIn('RUN SESSION TESTS: %d assertions, %d failures', (ROOT / runner).read_text())
        self.assertEqual({p for p, names in self.manifest["profiles"].items() if name in names},
                         {"core", "gameplay", "full"})
        for path in ("game/application/run_session.gd", runner):
            for stage in ("development", "integration"):
                plan = self.plan([path], stage)
                self.assertEqual(plan["selection"], "full")
                self.assertIn(name, plan["checks"])
                if stage == "integration":
                    self.assertIn(name, plan["ci_lane_checks"]["serial"])
                    self.assertNotIn(name, plan["ci_lane_checks"]["parallel"])

    def test_migrated_runtime_inputs_invalidate_real_cache_contracts_without_widening_pure_checks(self):
        import harness
        for name, check in self.manifest["checks"].items():
            if any(root in check.get("inputs", []) for root in ("scripts", "scripts/**")):
                self.assertIn("game", check["inputs"], name)
        path = "game/application/run_session.gd"
        for name in ("run-session", "core", "generated-consumers", "forest-campaign", "connected-family-tests",
                     "underworld-scenery", "underworld-hazards", "underworld-pipeline", "underworld-raw-export",
                     "visual-director-terrain"):
            check = self.manifest["checks"][name]
            before = harness.input_digest(check, [path], {}, {path: "a" * 64})
            after = harness.input_digest(check, [path], {}, {path: "b" * 64})
            self.assertNotEqual(before, after, name + " must not reuse proof for changed RunSession")
        for name in ("asset-family-tests", "item-v5-data", "item-authoring-tools", "cloud-production-planner-tests"):
            self.assertNotIn("game", self.manifest["checks"][name]["inputs"], name)

    def test_plains_motion_loot_is_a_real_registered_native_case_with_group_closure(self):
        # Importing the adapter reads its registry; it does not start Godot.
        from run_integration_four_tests import CASES
        name = "plains-motion-loot-02"
        check = self.manifest["checks"][name]
        self.assertEqual(check["argv"], ["python3", "tools/run_integration_four_tests.py", "--case", name])
        self.assertEqual(CASES[name], (
            "tests/plains_motion_loot_02_runner.gd",
            r"PLAINS MOTION LOOT02: [1-9]\d* assertions, 0 failures", 240))
        self.assertEqual(check["timeout_seconds"], 360)
        self.assertEqual(check["success_pattern"], "^" + CASES[name][1] + "$")
        self.assertEqual(check["artifact_paths"], ["build/plains_motion_loot_02/native.json"])
        self.assertEqual({profile for profile, names in self.manifest["profiles"].items() if name in names},
                         {"gameplay", "art", "full"})
        for profile in ("gameplay", "art", "full"):
            self.assertEqual(self.manifest["profiles"][profile].count(name), 1)
        runner = ROOT / CASES[name][0]
        self.assertTrue(runner.is_file())
        source = runner.read_text()
        for fixture in ("motion", "loot", "audio", "app"):
            path = "tests/plains_motion_loot_02_" + fixture + ".gd"
            self.assertIn('load("res://' + path + '").run(', source)
            self.assertTrue((ROOT / path).is_file())
            self.assertTrue(any(path == item or path.startswith(item.rstrip("/") + "/")
                                for item in check["inputs"]))
        integration = self.plan(["game/application/demo_app.gd"], "integration")
        self.assertIn(name, integration["checks"])
        self.assertIn(name, integration["ci_lane_checks"]["parallel"])
        self.assertNotIn(name, integration["ci_lane_checks"]["serial"])

    def exercise_main(self, script, action="--precheck-only", verbose=False):
        directory = tempfile.TemporaryDirectory(); self.addCleanup(directory.cleanup)
        root=Path(directory.name)
        (root/"tests").mkdir(); (root/"tools").mkdir()
        (root/"source.txt").write_text("frozen")
        (root/"tests/portable.py").write_text(script)
        (root/"tools/harness.py").write_text("from pathlib import Path; Path('engine-started').touch()")
        policy=copy.deepcopy(self.policy)
        policy["early_python_checks"][0]["argv"]=["python3","-S","tests/portable.py"]
        policy_path=root/"policy.json"; policy_path.write_text(json.dumps(policy))
        def metadata():
            return {"working_files":{"source.txt":hashlib.sha256((root/"source.txt").read_bytes()).hexdigest()}}
        harness=types.SimpleNamespace(load_manifest=lambda:self.manifest,
                    changed_paths=lambda base:["game/application/demo_app.gd"],git_metadata=metadata,
                    MANIFEST=ROOT/"tools/harness/profiles.json")
        stdout=io.StringIO(); output=root/"build/plan.json"
        with patch.object(production_plan,"ROOT",root), patch.object(production_plan,"POLICY",policy_path), patch.object(production_plan,"git",return_value="frozen-source"), patch.dict(sys.modules,{"harness":harness}), contextlib.redirect_stdout(stdout):
            argv=["--stage","integration",action,"--output",str(output)]
            if verbose: argv.append("--verbose-plan")
            try:
                result=production_plan.main(argv)
            except RuntimeError as error:
                result=error
        return root,result,stdout.getvalue(),json.loads(output.read_text()),json.loads(output.with_name("plan.execution.json").read_text()) if output.with_name("plan.execution.json").exists() else None

    def test_actual_precheck_is_portable_and_does_not_execute_engine_or_claim_full(self):
        root,code,stdout,plan,receipt=self.exercise_main("import sys; assert not sys.flags.no_site == 0")
        self.assertEqual(code,0)
        self.assertFalse((root/"engine-started").exists())
        self.assertEqual(receipt["approval_scope"],"precheck_only")
        self.assertEqual(receipt["status"],"selected_prechecks_succeeded")
        self.assertEqual(len(receipt["steps"]),1)
        self.assertIn("path_reasons",plan)
        self.assertNotIn('"path_reasons"',stdout)
        self.assertIn("Complete plan artifact:",stdout)
        self.assertLess(len(stdout),2000)
        _,code,verbose,_,_=self.exercise_main("pass",verbose=True)
        self.assertEqual(code,0)
        self.assertIn('"path_reasons"',verbose)

    def test_precheck_failure_stops_actual_planned_harness_execution(self):
        root,code,_,_,receipt=self.exercise_main("raise SystemExit(19)",action="--execute")
        self.assertEqual(code,19)
        self.assertFalse((root/"engine-started").exists())
        self.assertEqual(receipt["status"],"failed_or_interrupted")
        self.assertEqual(len(receipt["steps"]),1)

    def test_precheck_source_mutation_fails_guard_and_preserves_failure_receipt(self):
        root,result,_,_,receipt=self.exercise_main("from pathlib import Path; Path('source.txt').write_text('changed')")
        self.assertIsInstance(result,RuntimeError)
        self.assertEqual(receipt["status"],"failed_or_interrupted")
        self.assertFalse((root/"engine-started").exists())

if __name__ == "__main__":
    unittest.main(verbosity=2)
