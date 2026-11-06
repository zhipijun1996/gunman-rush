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
            paths = ['project.godot', 'scripts/legacy.gd', 'game/application/run_session.gd', 'experiments/terrain/probe.gd',
                     'build/output.gd', 'docs/evidence/frozen.gd']
            for name in paths:
                path = root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text('original')
            before = level_design.source_files(root)
            self.assertEqual(set(before), {'project.godot', 'scripts/legacy.gd', 'game/application/run_session.gd', 'experiments/terrain/probe.gd'})
            (root / 'game/application/run_session.gd').write_text('changed owner')
            self.assertNotEqual(before, level_design.source_files(root))
            added = root / 'game/application/new_untracked.gd'; added.write_text('new consumer')
            self.assertIn('game/application/new_untracked.gd', level_design.source_files(root))
            added.unlink()
            self.assertNotIn('game/application/new_untracked.gd', level_design.source_files(root))
            current = level_design.source_files(root)
            (root / 'experiments/terrain/probe.gd').write_text('changed experiment')
            self.assertNotEqual(current, level_design.source_files(root))
            extra = root / 'experiments/terrain/new_untracked.gd'; extra.write_text('new preview')
            self.assertIn('experiments/terrain/new_untracked.gd', level_design.source_files(root))
            extra.unlink()
            self.assertNotIn('experiments/terrain/new_untracked.gd', level_design.source_files(root))














    def test_spatial_experiment_exact_lease_refuses_core_and_directory_authorization(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root/'experiment.json'
            data = {'schema_version': 1, 'region_id': 'windchime_plains',
                    'authorization_basis': 'SIMULATED explicit bounded geometry/camera authorization',
                    'design': {'space': 'One playable against-wind room'},
                    'validation': ['Actual Motor traversal and whole-screen normal-speed independent review'],
                    'allowed_paths': ['game/world/generation/plains_spatial_golden.gd', 'game/world/generation/stage_camera_rig.gd', 'game/application/demo_app.gd']}
            level_design.write(path, data)
            _, binding = level_design.load_spatial_experiment('experiment.json', 'windchime_plains', root)
            self.assertEqual(binding['allowed_paths'], data['allowed_paths'])
            for allowed in ('scripts/demo/demo_app.gd', 'game/application/demo_app.gd',
                            'game/world/components/module_moving_platform.gd',
                            'game/world/components/module_moving_platform.gd.uid',
                            'game/world/components/scenes/checkpoint.tscn',
                            'game/presentation/effects/art/defeat_burst.gd',
                            'experiments/terrain/art/light_study.gd',
                            'experiments/motion/entries/graybox.tscn'):
                data['allowed_paths'] = [allowed]; level_design.write(path, data)
                self.assertEqual(level_design.load_spatial_experiment('experiment.json', 'windchime_plains', root)[1]['allowed_paths'], [allowed])
            for bad in ('scripts/generation/', 'assets/spatial_golden/*', 'scripts/actors/player_motor.gd',
                        'game/combat/weapons/weapon_catalog.gd', 'game/platform/persistence/meta_save_service.gd',
                        'config/player_tuning.json', 'game/world/generation/movement_capability_envelope.gd', '../outside.gd',
                        'scripts/run/demo_lifetime.gd', 'game/world/state/demo_lifetime.gd',
                        'scripts/run/run_profile.gd', 'game/world/state/run_profile.gd',
                        'scripts/run/route_planner.gd', 'game/world/state/route_planner.gd',
                        'scripts/player/graybox.gd', 'experiments/motion/graybox.gd',
                        'scripts/world/checkpoint.gd', 'game/world/components/checkpoint.gd',
                        'scripts/damage/damage_return_echo.gd', 'game/presentation/effects/damage_return_echo.gd',
                        'scripts/style_exploration/style_scenery.gd', 'game/presentation/world/style_exploration/style_scenery.gd'):
                data['allowed_paths'] = [bad]; level_design.write(path, data)
                with self.subTest(path=bad), self.assertRaises(ValueError):
                    level_design.load_spatial_experiment('experiment.json', 'windchime_plains', root)


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

    def test_short_route_cli_refuses_without_writing_mission(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / 'forest.json'
            with self.assertRaisesRegex(ValueError, 'retired'):
                level_design.main(['route', '--request', '制作荆棘森林', '--output', str(output)])
            self.assertFalse(output.exists())


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
            for heading in ("适用任务", "操作", "验证与交付"):
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

    def test_fixed_patched_engine_format_rejects_other_build_hash_and_mixed_banners(self):
        from godot_identity import expected_version
        selected = expected_version()
        core, _commit = selected.rsplit('.', 1)
        major, minor, patch, status, build = core.split('.', 4)
        engine = f"{major}.{minor}.{patch}-{status} ({build})"
        banner = 'Godot Engine v' + selected + ' - https://godotengine.org\n'
        historical = 'Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org\n'
        self.assertTrue(level_design.engine_log_matches(engine, banner))
        for wrong in (selected.replace(build, 'custom_build.unrelated'), core + '.000000000'):
            self.assertFalse(level_design.engine_log_matches(engine, 'Godot Engine v' + wrong + '\n'))
        self.assertFalse(level_design.engine_log_matches(engine, banner + historical))
        self.assertFalse(level_design.engine_log_matches('4.7.2-stable (official)', historical + banner))


if __name__ == "__main__":
    unittest.main()
