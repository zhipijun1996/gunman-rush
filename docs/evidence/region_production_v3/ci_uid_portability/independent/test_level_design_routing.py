"""Routing and honest-evidence boundary tests; no simulated tests labelled Motor."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from argparse import Namespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import level_design
import production_loop


class RoutingTests(unittest.TestCase):
    def test_short_forest_default_auto_is_bounded_native_prototype_with_full_plan_retained(self):
        mission=level_design.route_request('制作荆棘森林')
        production_loop.validate(mission)
        self.assertEqual(mission['phase'],'prototype')
        self.assertEqual(len(mission['tasks']),1)
        self.assertEqual(len(mission['production_plan']),9)
        task=mission['tasks'][0]
        self.assertIn('forest-h-slice',task['checks'])
        self.assertEqual(task['required_gates'],['G0','G1'])
        self.assertEqual(task['region_proof']['allowed_capabilities'],['H'])
        self.assertEqual(task['region_proof']['scope'],'prototype')
        self.assertIn('scripts/demo/thorn_forest_h_slice.gd.uid',task['allowed_paths'])
        self.assertIn('tests/forest_h_slice_runner.gd.uid',task['allowed_paths'])
        self.assertEqual(task['region_proof']['capability_gate']['alternatives'],[['H']])
        self.assertFalse(mission['preparation']['production_boundary']['formal_opening_authorized'])
        self.assertEqual(mission['preparation']['region_context']['implementation']['formal_region'],'no_formal_consumer_observed')
        self.assertEqual(mission['max_calls'],4)
        self.assertEqual(mission['max_rounds'],2)
        full=level_design.route_request('制作荆棘森林',phase='production')
        self.assertEqual(full['phase'],'production')
        self.assertEqual(full['tasks'],mission['production_plan'])

    def test_only_new_untracked_unreferenced_known_uid_sidecars_are_cleaned(self):
        from run_forest_h_slice_tests import preserve_new_unreferenced_uids, DEV_UIDS
        for protected in ('new','existing','tracked','referenced','untracked_scene','tracked_gd','untracked_gd','binary_consumer','unresolved_source'):
            with self.subTest(protected=protected),tempfile.TemporaryDirectory() as temp:
                root=Path(temp);path=root/DEV_UIDS[0];path.parent.mkdir(parents=True);path.write_text('uid://simulated_fixture\n')
                unrelated=root/'unrelated.gd.uid';unrelated.write_text('uid://leave_me\n')
                tracked=[];before={}
                if protected=='existing':before[DEV_UIDS[0]]=True
                elif protected=='tracked':tracked=[DEV_UIDS[0]]
                elif protected in ('referenced','untracked_scene'):
                    scene=root/'scenes/test.tscn';scene.parent.mkdir();scene.write_text('[ext_resource uid="uid://simulated_fixture"]')
                    if protected=='referenced':tracked=['scenes/test.tscn']
                elif protected in ('tracked_gd','untracked_gd'):
                    script=root/'actual_consumer.gd';script.write_text('const SAMPLE = preload("uid://simulated_fixture")')
                    if protected=='tracked_gd':tracked=['actual_consumer.gd']
                elif protected=='binary_consumer':
                    (root/'runtime.scn').write_bytes(b'opaque Godot binary scene; UID absence unknown')
                elif protected=='unresolved_source':
                    (root/'source.gd').symlink_to(root/'missing_source.gd')
                result=preserve_new_unreferenced_uids(root,before,tracked,root/'archive')
                self.assertTrue(unrelated.exists())
                self.assertEqual(path.exists(),protected!='new')
                if protected=='new':
                    self.assertTrue(result[0]['removed']);self.assertEqual((root/'archive'/DEV_UIDS[0]).read_text(),'uid://simulated_fixture\n')

    def test_actual_unprivileged_uid_directory_denial_is_not_unreferenced(self):
        # Keep the real chmod/euid regression on the original Harness route entry.
        from test_forest_uid_preservation import run_actual_case
        result=run_actual_case('denied_reference')
        if os.geteuid() == 0:
            self.assertEqual(result['euid'],1000)
        else:
            self.assertEqual(result['euid'],os.geteuid())
        self.assertNotEqual(result['euid'],0)
        self.assertTrue(result['actual_directory_permission_denied'])
        self.assertTrue(result['uid_preserved'],result)
        self.assertTrue(result['preserved_original_bytes'],result)
        self.assertFalse(result['archive_exists'],result)

    def test_real_short_route_cli_needs_no_prototype_flag(self):
        with tempfile.TemporaryDirectory() as folder:
            output=Path(folder)/'forest.json'
            self.assertEqual(level_design.main(['route','--request','制作荆棘森林','--output',str(output)]),0)
            mission=level_design.read(output)
            self.assertEqual(mission['phase'],'prototype')
            self.assertIn('forest-h-slice',mission['tasks'][0]['checks'])
            self.assertEqual(mission['preparation']['region_context']['design']['stage']['value'],'S2')

    def test_forest_professional_prework_has_real_independent_dependencies(self):
        mission=level_design.route_request('制作荆棘森林',phase='production')
        production_loop.validate(mission)
        tasks={t['id'].removeprefix('level-new_region-'):t for t in mission['tasks']}
        self.assertEqual(list(tasks),['audit','design','ecology','boss','assets','animation','golden','integration','review'])
        for role,skill in [('ecology','enemy-creator'),('boss','boss-creator'),('assets','visual-director'),('animation','animation-vfx')]:
            self.assertIn(skill,tasks[role]['skills'])
            self.assertNotIn(tasks['golden']['id'],tasks[role]['depends_on'])
            self.assertIn('G0',tasks[role]['required_gates'])
            self.assertEqual(tasks[role]['region_proof']['region_id'],'thorn_forest')
        for role in ('ecology','boss','assets'):
            self.assertEqual(tasks[role]['depends_on'],[tasks['design']['id']])
            self.assertIn(tasks[role]['id'],tasks['golden']['depends_on'])
        self.assertIn('G2',tasks['assets']['required_gates'])
        self.assertIn('G2',tasks['animation']['required_gates'])
        self.assertEqual(tasks['integration']['depends_on'],[tasks['golden']['id']])
        self.assertEqual(tasks['review']['quality_task_id'],tasks['integration']['id'])

    def test_forest_proof_boundary_preserves_authority_without_formal_grant(self):
        mission=level_design.route_request('制作荆棘森林',phase='production')
        context=mission['preparation']['region_context']
        self.assertEqual(context['design']['stage']['value'],'S2')
        self.assertEqual(context['design']['gate']['alternatives'],[['H']])
        boundary=mission['preparation']['production_boundary']
        self.assertFalse(boundary['formal_opening_authorized'])
        self.assertFalse(boundary['shared_regression_is_region_proof'])
        self.assertEqual(boundary['runtime_status']['formal_region'],'no_formal_consumer_observed')
        self.assertIsNone(boundary['runtime_status']['runtime_available'])
        for task in mission['tasks'][2:]:
            contract=task['region_proof']
            self.assertEqual(contract['region_id'],'thorn_forest')
            self.assertEqual(contract['capability_gate']['alternatives'],[['H']])
            expected='formal' if task['id'].endswith(('integration','review')) else 'prototype'
            self.assertEqual(contract['scope'],expected)
        self.assertEqual(mission['scope'],'offline_production_plan_not_executed')

    def test_mutable_design_registers_new_tasks_before_quality_profiles(self):
        for request in ("优化风铃平原", "制作荆棘森林"):
            mission=level_design.route_request(request,phase="production")
            prerequisite=mission["preparation"]["task_registration"]
            self.assertEqual(prerequisite["source"],"AGENTS.md")
            self.assertEqual(prerequisite["paths"],["docs/tasks.md","docs/quality/records/"])
            self.assertEqual(prerequisite["phase"],"design")
            self.assertTrue(prerequisite["before_quality_profile"])
            self.assertIn("every new task ID",prerequisite["requirement"])
            design=mission["tasks"][1]
            self.assertFalse(design["read_only"])
            self.assertIn("docs/",design["allowed_paths"])
            self.assertIn("docs/tasks.md",design["goal"])
            self.assertIn("再执行quality profile",design["goal"])

    def test_existing_region_uses_shared_skills_and_checks(self):
        mission = level_design.route_request("优化风铃平原，这里无聊且重复")
        production_loop.validate(mission)
        self.assertEqual(mission["workflow"], "optimize")
        self.assertEqual(len(mission["steps"]), 10)
        self.assertTrue(mission["tasks"][-1]["read_only"])
        self.assertEqual(mission["human_acceptance"], "unverified")

    def test_new_biome_routes_full_pipeline_without_region_constants(self):
        for request in ("制作荆棘森林", "create glacier region", "制作未知的地下河地区"):
            mission = level_design.route_request(request,phase="production")
            production_loop.validate(mission)
            self.assertEqual(mission["workflow"], "new_region")
            self.assertEqual(len(mission["steps"]), 14)
            self.assertIn("scene-composer", mission["tasks"][1]["skills"])
            self.assertNotIn("PlainsRegionGenerator", json.dumps(mission))
            paths = mission["tasks"][3]["allowed_paths"]
            for path in ("scripts/bosses/", "resources/bosses/", "scripts/world/", "resources/art/", "scripts/audio/"):
                self.assertIn(path, paths)
            for path in ("scripts/player/", "scripts/save/", "scripts/run/", "config/"):
                self.assertNotIn(path, paths)
            self.assertEqual(mission["tasks"][1]["allowed_paths"], ["docs/", "tests/", "tools/"])

    def test_ambiguous_and_empty_do_not_silently_authorize_new_region(self):
        for request in ("", "看看地图", "制作新区域并优化旧区域"):
            with self.assertRaises(ValueError):
                level_design.route_request(request)
        self.assertEqual(level_design.route_request("看看地图", "optimize")["workflow"], "optimize")

    def test_invalid_skill_or_check_cannot_pass_routing(self):
        mission = level_design.route_request("优化风铃平原")
        mission["tasks"][1]["checks"] = ["imaginary-fun-95"]
        with self.assertRaises(ValueError):
            production_loop.validate(mission)

    def test_json_duplicate_and_nonfinite_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "bad.json"
            for content in ('{"ok":true,"ok":false}', '{"value":NaN}'):
                path.write_text(content)
                with self.assertRaises(ValueError):
                    level_design.read(path)

    def test_skill_discovery_and_required_workflow_sections(self):
        for name in ("challenge-choreographer", "encounter-director", "scene-composer"):
            path = level_design.ROOT / ".agents/skills" / name / "SKILL.md"
            text = path.read_text()
            self.assertIn("name: " + name, text)
            for heading in ("触发与边界", "输入与依赖", "自动验收", "人工审查", "准入退出与返工", "完成与证据"):
                self.assertIn("## " + heading, text)

    def test_unreceipted_json_is_not_a_fresh_motor_proof_and_bad_receipt_fails(self):
        from test_level_design_analysis import capture
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "capture.json"
            target = Path(folder) / "report.json"
            level_design.write(source, capture())
            args = Namespace(capture=str(source), output=str(target), policy=None, evidence=[])
            self.assertEqual(level_design.analyze(args), 0)
            self.assertEqual(level_design.read(target)["provenance"]["status"], "unverified")
            comparison = Path(folder) / "comparison.json"
            self.assertEqual(level_design.main(["compare", "--before", str(target), "--after", str(target),
                                                "--output", str(comparison)]), 0)
            self.assertEqual(level_design.read(comparison)["verdict"], "REVIEW")
            level_design.write(source.with_suffix(".invocation.json"), {"exit_code": 0, "capture_sha256": "wrong"})
            self.assertEqual(level_design.analyze(args), 1)
            self.assertEqual(level_design.read(target)["verdict"], "REJECT")

    def test_complete_receipt_consistency_and_mutations(self):
        # Synthetic contract test only; the engine specialty proves actual execution.
        from test_level_design_analysis import capture
        import copy
        (level_design.ROOT / "build").mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=level_design.ROOT / "build") as folder:
            source = Path(folder) / "capture.json"
            log = source.with_suffix(".log")
            data = capture()
            data.update(scope="formal_manifest_and_assembler_shotlatch_traces_not_enemy_or_boss_completion",
                        assertions=3, failures=[], formal_run_manifest={"root_seed": "fixture"},
                        engine="4.7.2-stable (official)")
            level_design.write(source, data)
            log.write_text("Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org\nLEVEL DESIGN CAPTURE: 3 assertions, 0 failures, 1 traces\n")
            relative = source.relative_to(level_design.ROOT).as_posix()
            receipt = {"schema_version": 1, "scope": "actual_godot_process", "exit_code": 0,
                       "capture": relative, "capture_sha256": level_design.file_hash(source),
                       "source_commit": data["source_commit"], "source_files": {"fixture": "before"},
                       "log_sha256": level_design.file_hash(log),
                       "command": ["bash", "tools/godot.sh", "--headless", "--fixed-fps", "60", "--path", ".", "--script",
                                   "tools/level_design_capture.gd", "--", "--source-commit=" + data["source_commit"],
                                   "--seed=fixture", "--strategies=fast", "--output=res://" + relative]}
            self.assertEqual(level_design.validate_receipt(source, data, receipt, log, {"fixture": "before"}), [])
            for key in receipt:
                bad = copy.deepcopy(receipt)
                del bad[key]
                self.assertTrue(level_design.validate_receipt(source, data, bad, log, {"fixture": "before"}), key)
            self.assertTrue(level_design.validate_receipt(source, data, receipt, log, {"fixture": "after"}))
            for text in ("not engine evidence", "Godot Engine v" + data["engine"] + "\nLEVEL DESIGN CAPTURE: 3 assertions, 0 failures, 1 traces\nSCRIPT ERROR: bad"):
                log.write_text(text)
                bad = copy.deepcopy(receipt)
                bad["log_sha256"] = level_design.file_hash(log)
                self.assertTrue(level_design.validate_receipt(source, data, bad, log, {"fixture": "before"}))

    def test_real_engine_version_formats_and_mismatches(self):
        banner = "Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org\n"
        self.assertTrue(level_design.engine_log_matches("4.7.2-stable (official)", banner))
        for engine in ("4.6.3-stable (official)", "4.7.2-beta (official)", "4.7.2-stable (custom)", "4.7.2", ""):
            self.assertFalse(level_design.engine_log_matches(engine, banner))
        self.assertFalse(level_design.engine_log_matches("4.7.2-stable (official)", banner + banner.replace("4.7.2", "4.6.3")))


if __name__ == "__main__":
    unittest.main()
