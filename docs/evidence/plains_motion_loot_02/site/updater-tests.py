"""Pure preparation-model regression. No movie/Godot/Sites mutation is claimed."""
import copy
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import tempfile
import subprocess
import unittest

SPEC = importlib.util.spec_from_file_location('updater', '/tmp/add_plains_motion_loot_02_catalog.py')
u = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(u)


def fixture():
    cases, rows = [], []
    info = {'duration': 30., 'frames': 1800, 'fps': 60, 'game_commit': 'a' * 40,
            'media_commit': 'c' * 40, 'media_sha256': 'b' * 64,
            'media_id': 'plains-motion-loot-' + 'b' * 12,
            'source_video_url': 'https://raw.githubusercontent.com/zhipijun1996/gunman-rush/' + 'c' * 40 + '/docs/evidence/test.mp4',
            'video_url': '/media/plains-motion-loot-' + 'b' * 12}
    for i, (behavior, species) in enumerate(zip(u.BEHAVIORS, u.CAPTURE_SPECIES)):
        start = i * 180 + 30
        total = 7 if behavior == 'root_bell' else 1
        values = [5, 1, 1] if total == 7 else [1]
        final_units = [{'id': f'{species}/coin/{n}', 'kind': 'coin', 'amount': v, 'claimed': True} for n, v in enumerate(values)]
        if behavior == 'root_bell':
            final_units.append({'id': species + '/heart', 'kind': 'heart', 'amount': 1, 'claimed': True})
        base = len(rows)
        case = dict(case=i, id=species, behavior=behavior, start_seconds=start / 60,
                    end_seconds=(start + 120) / 60, coverage_gaps=[], original_manifest_unchanged=True,
                    coverage={'synthetic_acceptance_fact': True}, configured_coin_total=total,
                    actual_wallet_delta=total, deaths=1, inputs=[{'fixture': True}], shots=[{'fixture': True}],
                    events=[{'frame': base + 3, 'movie_frame': start + 20, 'terminal': False, 'amount': -1},
                            {'frame': base + 5, 'movie_frame': start + 40, 'terminal': True, 'amount': -1}],
                    player_events=[{'amount': 1, 'movie_frame': start + 70}] if behavior == 'root_bell' else [],
                    final_units=final_units)
        cases.append(case)
        for n in range(8):
            units = copy.deepcopy(final_units) if n >= 4 else []
            for item in units:
                item.update(claimed=n >= 7, bounces=1 if n >= 5 else 0, settled=n >= 6)
            rows.append(dict(frame=base + n + 1, case=i, rendered_movie_process_frame=start + n * 10,
                             sampling_phase='read-only frame_post_draw confirms preceding process sample',
                             idle_hold=n < 2, AI_enabled=n >= 2, drive=.8 if n >= 2 else 0.,
                             HP=2 if n < 4 else 0, units=units,
                             collected_coin_total=total if n >= 7 else 0))
    trace = dict(task='PLAINS-MOTION-LOOT-02', kind='actual_App_staged_review', complete=True,
                 whole_roster=True, selected_behaviors=list(u.BEHAVIORS), source_stable=True,
                 source_before={'res://synthetic_fixture.gd': 'e' * 64}, source_after={'res://synthetic_fixture.gd': 'e' * 64},
                 failures=[], coverage_gap_count=0, frames=rows, cases=cases,
                 actual_heal_observed=True, root_7_equals_5_1_1=True,
                 audio_teardown=[{'released': True} for _ in cases],
                 git_before={'head': 'a' * 40, 'status': '', 'head_exit_code': 0, 'status_exit_code': 0},
                 git_after={'head': 'a' * 40, 'status': '', 'head_exit_code': 0, 'status_exit_code': 0})
    return info, trace


class Tests(unittest.TestCase):
    def setUp(self):
        self.info, self.trace = fixture()
        self.directory = tempfile.TemporaryDirectory()
        d = Path(self.directory.name)
        self.args = SimpleNamespace(game_commit='a' * 40, movie=d / 'synthetic.bin', trace=d / 'trace.json')
        self.args.movie.write_bytes(b'pure test input; not a recording')
        self.args.trace.write_text(json.dumps(self.trace))
        source = {'commit': 'a' * 40, 'git_status': '', 'working_files': {}, 'untracked': ''}
        self.report = dict(status='recorded_complete_coverage', source_stable=True, whole_roster=True,
                           selected_behaviors=list(u.BEHAVIORS), source=source, source_after=source,
                           source_files_before={'synthetic': 'f' * 64}, source_files_after={'synthetic': 'f' * 64},
                           execution={'status': 'passed', 'exit_code': 0, 'failure_reason': None},
                           mp4_sha256=u.sha(self.args.movie), trace_sha256=u.sha(self.args.trace))

    def tearDown(self):
        self.directory.cleanup()

    def test_source_model_and_bounded_new_versions(self):
        cases, rows = u.validate_capture(self.report, self.trace, self.args, self.info)
        variants, selections, proofs = u.variants_from_trace(cases, rows, self.info)
        self.assertEqual(len(variants), 7); self.assertEqual(len(selections), 7); self.assertEqual(len(proofs), 7)
        self.assertEqual(variants['plains_root_bell']['actions'][9]['status'], 'recorded')
        self.assertTrue(all(next(a for a in v['actions'] if a['id'] == 'hurt_recovery')['status'] == 'missing' for v in variants.values()))
        self.assertTrue(all(next(a for a in v['actions'] if a['id'] == 'note_drop')['status'] == 'missing' for v in variants.values()))

    def test_only_exact_recorded_patrol_identity_maps_to_retained_catalog_id(self):
        variants, _, proofs = u.variants_from_trace(self.trace['cases'], self.trace['frames'], self.info)
        self.assertIn('patrol_drone', variants)
        self.assertNotIn('graybox_patrol_drone', variants)
        self.assertEqual(proofs[0]['recorded_monster_id'], 'graybox_patrol_drone')
        for identity in ('patrol_drone', 'graybox_patrol_drone_unknown'):
            trace = copy.deepcopy(self.trace)
            trace['cases'][0]['id'] = identity
            with self.subTest(identity=identity), self.assertRaises(ValueError):
                u.validate_capture(self.report, trace, self.args, self.info)

    def test_poster_is_an_actual_confirmed_frame_inside_playable_interval(self):
        trace = copy.deepcopy(self.trace)
        trace['cases'][0]['start_seconds'] += 1 / 60
        variants, selections, _ = u.variants_from_trace(trace['cases'], trace['frames'], self.info)
        first = variants['patrol_drone']
        chosen = selections[0]['frame']
        self.assertGreaterEqual(chosen / 60, first['in'])
        self.assertLess(chosen / 60, first['out'])
        self.assertIn(chosen, [r['rendered_movie_process_frame'] for r in trace['frames'] if r['case'] == 0])

    def test_exact_retained_catalog_and_other18_unchanged(self):
        source = u.SITE / 'data/catalog.json'
        checksum = u.sha(source); before = json.loads(subprocess.check_output(['git', '-C', str(u.SITE), 'show', 'ec916080ffae288332c233cf01906fa02eeeb561:data/catalog.json']))
        self.assertEqual(u.catalog_counts(before), {'monsters': 25, 'variants': 88, 'media': 14})
        variants, _, _ = u.variants_from_trace(self.trace['cases'], self.trace['frames'], self.info)
        after = u.merge_catalog(before, variants, self.info['game_commit'])
        self.assertEqual(u.catalog_counts(after), {'monsters': 25, 'variants': 95, 'media': 15})
        self.assertEqual(u.sha(source), checksum)
        with self.assertRaises(ValueError):
            u.merge_catalog(after, variants, self.info['game_commit'])

    def test_bad_reports_refused(self):
        variants = [dict(status='failed'), dict(source_stable=False), dict(whole_roster=False),
                    dict(selected_behaviors=list(reversed(u.BEHAVIORS))), dict(mp4_sha256='0' * 64),
                    dict(trace_sha256='0' * 64), dict(execution={'status': 'passed', 'exit_code': 1}),
                    dict(source={**self.report['source'], 'git_status': ' M fake'})]
        for changes in variants:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                u.validate_capture({**self.report, **changes}, self.trace, self.args, self.info)

    def test_false_coverage_and_payout_and_root_values_refused(self):
        for mutation in ('coverage', 'boolean_amount', 'wrong_total', 'repeat_death', 'wrong_root_units', 'missing_source'):
            trace = copy.deepcopy(self.trace)
            if mutation == 'coverage': trace['cases'][0]['coverage']['synthetic_acceptance_fact'] = False
            if mutation == 'boolean_amount': trace['cases'][0]['configured_coin_total'] = True
            if mutation == 'wrong_total': trace['cases'][0]['actual_wallet_delta'] = 2
            if mutation == 'repeat_death': trace['cases'][0]['events'].append(trace['cases'][0]['events'][-1])
            if mutation == 'wrong_root_units': trace['cases'][-1]['final_units'][0]['amount'] = 4
            if mutation == 'missing_source': trace['source_before']['res://synthetic_fixture.gd'] = 'missing'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                u.validate_capture(self.report, trace, self.args, self.info)

    def test_missing_postdraw_or_bad_coin_progress_refused(self):
        for kind in ('no_postdraw', 'reversed_movie_frames', 'wallet_regression'):
            trace = copy.deepcopy(self.trace)
            if kind == 'no_postdraw':
                for r in trace['frames']: r.pop('rendered_movie_process_frame')
            if kind == 'reversed_movie_frames': trace['frames'][1]['rendered_movie_process_frame'] = 1
            if kind == 'wallet_regression':
                trace['frames'][5]['collected_coin_total'] = 1; trace['frames'][6]['collected_coin_total'] = 0
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                u.variants_from_trace(trace['cases'], trace['frames'], self.info)

    def test_current_site_apply_gate_fails_before_writes(self):
        before = u.sha(u.SITE / 'data/catalog.json')
        with self.assertRaises(ValueError):
            u.apply_to_opened_site(u.SITE, Path(self.directory.name), u.SITE / 'data/catalog.json', '0' * 40)
        self.assertEqual(u.sha(u.SITE / 'data/catalog.json'), before)


if __name__ == '__main__':
    unittest.main(verbosity=2)
