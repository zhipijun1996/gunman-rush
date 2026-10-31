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
    def test_runtime_snapshot_tracks_new_game_sources_but_not_build_or_evidence(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            paths = ['project.godot', 'scripts/legacy.gd', 'game/application/run_session.gd',
                     'build/output.gd', 'docs/evidence/frozen.gd']
            for name in paths:
                path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('original')
            before = level_design.source_files(root)
            self.assertEqual(set(before), {'project.godot', 'scripts/legacy.gd', 'game/application/run_session.gd'})
            (root / 'game/application/run_session.gd').write_text('changed owner')
            self.assertNotEqual(before, level_design.source_files(root))
            added = root / 'game/application/new_untracked.gd'; added.write_text('new consumer')
            self.assertIn('game/application/new_untracked.gd', level_design.source_files(root))
            added.unlink()
            self.assertNotIn('game/application/new_untracked.gd', level_design.source_files(root))


    def test_source_painting_rebuild_is_explicit_limited_real_consumer_route(self):
        import visual_director as vd
        request = '从源画重建风铃平原连续地貌与美术'
        historical = vd.historical_recipe_plan(request, 'historical-paint', 'docs/quality/records/historical-paint.json', ['scripts/art/'])
        recipe = historical['preparation']['visual_recipe']
        self.assertEqual(recipe['generation_profile'], 'plains-world-rebuild-v3')
        self.assertEqual(recipe['preview_script'], 'tools/plains_world_rebuild_preview.gd')
        self.assertEqual(recipe['capture_wrapper'], 'tools/run_plains_world_rebuild_tests.py')
        self.assertIsNone(recipe['capture_script'])
        self.assertIn('main_or_lower_only', recipe['capture_status'])
        current = level_design.route_request(request)
        production_loop.validate(current)
        self.assertEqual(current['region_bible']['bible_id'], 'windchime_plains_v2')
        self.assertNotIn('visual_recipe', current['preparation'])
        self.assertEqual(current['phase'], 'production')
        for request, region in [('制作风铃平原美术', 'windchime_plains'), ('从源画重建荆棘森林地貌美术', 'thorn_forest')]:
            self.assertFalse(level_design.world_rebuild_request(request, region))


    def test_module_art_language_uses_new_exact_candidate_not_failed_joint_profile(self):
        import visual_director as vd
        for request in ('优化风铃平原关卡美术语言', '改进风铃平原生成器美术参数', '设计风铃平原模块尺寸规格'):
            with self.subTest(request=request):
                historical = vd.historical_recipe_plan(request, 'historical-language', 'docs/quality/records/historical-language.json', ['scripts/art/'])
                recipe = historical['preparation']['visual_recipe']
                self.assertEqual(recipe['generation_profile'], 'bounded_plains_v1')
                self.assertEqual(recipe['preview_script'], 'tools/plains_art_language_preview.gd')
                self.assertIsNone(recipe['capture_script'])
                self.assertIn('not_bound', recipe['capture_status'])
                self.assertIn('plains-art-language-contract', historical['tasks'][1]['checks'])
                mission = level_design.route_request(request)
                production_loop.validate(mission)
                self.assertNotIn('visual_recipe', mission['preparation'])
                self.assertEqual(mission['region_bible']['region_id'], 'windchime_plains')
        self.assertFalse(level_design.art_language_request('设计荆棘森林关卡美术语言', 'thorn_forest'))


    def test_short_plains_art_uses_actual_existing_visual_recipe_without_mode_flags(self):
        for request in ('改善另一段风铃平原的美术', '制作风铃平原美术', '改善风铃平原的美术和玩法'):
            mission = level_design.route_request(request)
            production_loop.validate(mission)
            self.assertEqual(mission['scope'], 'offline_production_plan_not_executed')
            self.assertNotIn('visual_recipe', mission['preparation'])
            self.assertEqual(mission['creative_phase'], 'production')
            self.assertTrue(mission['native_import_preflight'])
            for task in mission['tasks']:
                self.assertEqual(task['region_bible'], mission['region_bible'])
                self.assertEqual(task['creative_direction']['region_id'], 'windchime_plains')
            golden = next(t for t in mission['tasks'] if t['id'].endswith('-golden'))
            self.assertEqual(golden['required_gates'], ['G0', 'G1', 'G2'])
            self.assertTrue(golden['requires_visual_admission'])


    def test_joint_landform_short_requests_use_existing_loop_with_exact_geometry_lease(self):
        import visual_director as vd
        for request in ('联合设计风铃平原关卡与美术，包括碰撞', '改善风铃平原地貌', '设计风铃平原模块语言', '重做风铃平原环境构造'):
            with self.subTest(request=request):
                historical = vd.historical_recipe_plan(request, 'historical-landform', 'docs/quality/records/historical-landform.json', ['scripts/art/'])
                recipe = historical['preparation']['visual_recipe']
                self.assertEqual(recipe['profile'], 'scripts/art/plains_joint_recoil_composer.gd')
                self.assertEqual(recipe['recipe'], 'docs/evidence/plains_landform/recipe.md')
                self.assertEqual(recipe['capture_script'], 'tools/plains_joint_recoil_capture.gd')
                self.assertEqual(recipe['expansion'], 'blocked_until_actual_art_and_operation_admission')
                self.assertIn('plains-landform-contract', historical['tasks'][1]['checks'])
                mission = level_design.route_request(request)
                production_loop.validate(mission)
                self.assertNotIn('visual_recipe', mission['preparation'])
                self.assertTrue(all(t['region_bible'] == mission['region_bible'] for t in mission['tasks']))


    def test_surface_only_and_core_requests_do_not_inherit_joint_geometry_authorization(self):
        import visual_director as vd
        for request in ('改善风铃平原调色，保持碰撞不变', '重做风铃平原地貌调色', '改善风铃平原换纹理'):
            with self.subTest(request=request):
                self.assertFalse(level_design.joint_landform_request(request, 'windchime_plains'))
                mission = level_design.route_request(request)
                self.assertEqual(mission['creative_phase'], 'production')
                self.assertNotIn('visual_recipe', mission['preparation'])
                self.assertTrue(any('Motor' in item for item in mission['constraints']))
        focused = vd.route('改善风铃平原调色，保持碰撞不变', 'current-surface', 'docs/quality/records/current-surface.json', ['scripts/art/'], phase='golden')
        self.assertEqual(focused['tasks'][0]['allowed_paths'], ['scripts/art/'])
        self.assertEqual(focused['tasks'][0]['region_bible']['bible_id'], 'windchime_plains_v2')


    def test_short_forest_default_auto_is_bounded_native_prototype_with_full_plan_retained(self):
        default=level_design.content_plan('制作荆棘森林')
        self.assertEqual(default['phase'], 'production')
        self.assertEqual(len(default['tasks']), 9)
        mission=level_design.content_plan('制作荆棘森林', phase='prototype')
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
        self.assertEqual(mission['preparation']['region_context']['implementation']['formal_region'],'consumer_present_in_source')
        self.assertEqual(mission['max_calls'],4)
        self.assertEqual(mission['max_rounds'],2)
        full=level_design.content_plan('制作荆棘森林',phase='production')
        self.assertEqual(full['phase'],'production')
        self.assertEqual(full['tasks'],mission['production_plan'])

    def test_public_production_golden_requires_joint_visual_admission_but_legacy_stays_explicit(self):
        legacy = level_design.content_plan('优化风铃平原', phase='production')
        self.assertEqual(legacy['tasks'][2]['required_gates'], ['G0', 'G1'])
        for request, region in (('优化风铃平原', 'windchime_plains'), ('制作荆棘森林', 'thorn_forest')):
            mission = level_design.route_request(request, direction='docs/creative_direction/'+region+'.json')
            production_loop.validate(mission)
            golden = next(t for t in mission['tasks'] if t['id'].endswith('-golden'))
            integration = next(t for t in mission['tasks'] if t['id'].endswith('-integration'))
            self.assertEqual(golden['required_gates'], ['G0', 'G1', 'G2'])
            self.assertTrue(golden['requires_visual_admission'])
            for skill in ('visual-director', 'scene-composer', 'encounter-director', 'animation-vfx'):
                self.assertIn(skill, golden['skills'])
            self.assertIn(golden['id'], integration['depends_on'])
            golden['required_gates'] = ['G0', 'G1']
            with self.assertRaisesRegex(ValueError, 'independent G2'):
                production_loop.validate(mission)

    def test_spatial_experiment_exact_lease_refuses_core_and_directory_authorization(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root/'experiment.json'
            data = {'schema_version': 1, 'region_id': 'windchime_plains',
                    'authorization_basis': 'SIMULATED explicit bounded geometry/camera authorization',
                    'design': {'space': 'One playable against-wind room'},
                    'validation': ['Actual Motor traversal and whole-screen normal-speed independent review'],
                    'allowed_paths': ['scripts/generation/plains_spatial_golden.gd', 'scripts/generation/stage_camera_rig.gd', 'scripts/demo/demo_app.gd']}
            level_design.write(path, data)
            _, binding = level_design.load_spatial_experiment('experiment.json', 'windchime_plains', root)
            self.assertEqual(binding['allowed_paths'], data['allowed_paths'])
            for bad in ('scripts/generation/', 'assets/spatial_golden/*', 'scripts/actors/player_motor.gd',
                        'scripts/combat/weapon_catalog.gd', 'scripts/save/meta_save_service.gd',
                        'config/player_tuning.json', 'scripts/generation/movement_capability_envelope.gd', '../outside.gd'):
                data['allowed_paths'] = [bad]; level_design.write(path, data)
                with self.subTest(path=bad), self.assertRaises(ValueError):
                    level_design.load_spatial_experiment('experiment.json', 'windchime_plains', root)

    def test_public_spatial_experiment_cli_binds_design_and_removes_broad_source_leases(self):
        (level_design.ROOT/'build').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=level_design.ROOT/'build') as tmp:
            folder = Path(tmp); path = folder/'experiment.json'; output = folder/'mission.json'
            allowed = ['scripts/generation/plains_spatial_golden.gd', 'scripts/demo/demo_app.gd',
                       'scripts/art/plains_spatial_golden_art.gd', 'assets/spatial_golden/foreground.png']
            level_design.write(path, {'schema_version': 1, 'region_id': 'windchime_plains',
                'authorization_basis': 'SIMULATED explicit experiment', 'design': {'one_space': True,
                    'direction_path': 'docs/creative_direction/windchime_plains.json',
                    'direction_sha256': level_design.file_hash(level_design.ROOT/'docs/creative_direction/windchime_plains.json')},
                'validation': ['Real gameplay, complete screen and normal speed video'], 'allowed_paths': allowed})
            relative = path.relative_to(level_design.ROOT).as_posix()
            self.assertEqual(level_design.main(['route', '--request', '优化风铃平原', '--direction',
                'docs/creative_direction/windchime_plains.json', '--spatial-experiment', relative, '--output', str(output)]), 0)
            mission = level_design.read(output)
            for task in mission['tasks']:
                if task['id'].endswith(('-design', '-golden')):
                    self.assertEqual(set(task['allowed_paths']), set(allowed + [task['quality_record'], 'docs/tasks.md']))
                    self.assertFalse(any(p.endswith('/') for p in task['allowed_paths']))
                    production_loop.spatial_experiment_input(task)
                    task['allowed_paths'].append('scripts/generation/')
                    with self.assertRaisesRegex(ValueError, 'exact authorized'):
                        production_loop.spatial_experiment_input(task)
                    task['allowed_paths'].pop()
            path.write_text(path.read_text()+' ')
            golden = next(t for t in mission['tasks'] if t['id'].endswith('-golden'))
            with self.assertRaisesRegex(ValueError, 'design/hash/write set changed'):
                production_loop.spatial_experiment_input(golden)
            with self.assertRaisesRegex(ValueError, 'selected direction'):
                level_design.route_request('制作风铃平原', phase='prototype', spatial_experiment=relative)

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
            self.assertEqual(mission['phase'],'production')
            self.assertEqual(mission['region_bible']['bible_id'],'thorn_forest_v2')
            self.assertEqual(len(mission['tasks']),9)
            self.assertEqual(mission['preparation']['region_context']['design']['stage']['value'],'S2')

    def test_forest_professional_prework_has_real_independent_dependencies(self):
        mission=level_design.content_plan('制作荆棘森林',phase='production')
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
        mission=level_design.content_plan('制作荆棘森林',phase='production')
        context=mission['preparation']['region_context']
        self.assertEqual(context['design']['stage']['value'],'S2')
        self.assertEqual(context['design']['gate']['alternatives'],[['H']])
        boundary=mission['preparation']['production_boundary']
        self.assertFalse(boundary['formal_opening_authorized'])
        self.assertFalse(boundary['shared_regression_is_region_proof'])
        self.assertEqual(boundary['runtime_status']['formal_region'],'consumer_present_in_source')
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
            mission=level_design.content_plan(request,phase="production")
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
        mission = level_design.content_plan("优化风铃平原，这里无聊且重复")
        production_loop.validate(mission)
        self.assertEqual(mission["workflow"], "optimize")
        self.assertEqual(len(mission["steps"]), 10)
        self.assertTrue(mission["tasks"][-1]["read_only"])
        self.assertEqual(mission["human_acceptance"], "unverified")

    def test_new_biome_routes_full_pipeline_without_region_constants(self):
        for request in ("制作荆棘森林", "create glacier region", "制作未知的地下河地区"):
            mission = level_design.content_plan(request,phase="production")
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
                level_design.content_plan(request)
        self.assertEqual(level_design.content_plan("看看地图", "optimize")["workflow"], "optimize")

    def test_invalid_skill_or_check_cannot_pass_routing(self):
        mission = level_design.content_plan("优化风铃平原")
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
