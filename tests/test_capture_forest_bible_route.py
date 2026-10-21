"""Finite synthetic route/media negatives, never native gameplay or listening proof."""
import copy
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import capture_forest_bible_route as av


class CaptureAcceptanceTests(unittest.TestCase):
    def fixture(self, challenge='F05'):
        index = 1 if challenge == 'F05' else 2
        route = 'bible_backbranch_journey' if challenge == 'F05' else 'bible_spiral_journey'
        ids = ['entry', 'bible_backbranch_flight', 'camp'] if challenge == 'F05' else ['interwoven_deep_ascent', 'reader', 'bible_spiral_other_exit']
        m = {'map_index': index, 'seed': f'SYNTHETIC/thorn_forest/map_{index}', 'layout_version': 'forest-bible-world-v15',
             'version': 'thorn-forest-region-v2', 'manifest_hash': 'a' * 64, 'spawn': [0, 0], 'merchant_position': [20, 0],
             'routes': {route: ids}, 'connections': [{'id': name, 'kind': 'walk', 'path': [[0, 0], [x, 0]]} for name, x in zip(ids, [0, 10, 20])]}
        config = {'tuning': av.sha(ROOT / 'config/player_tuning.json'), 'traversal': av.sha(ROOT / 'resources/player/traversal.tres')}
        initial = {'position': [0, 0], 'config': config, 'health': 5, 'hook_enabled': True, 'double_enabled': False,
                   'wall_enabled': False, 'weapon': 'pulse_gun', 'tier': 1}
        frames = [{'tick': i, 'position': [x, 0], 'health': 5, 'motor_steps': 1, 'actor_epoch': 3, 'stage_epoch': 3,
                   'shot_economy': {'owner_id': 11, 'session_id': 12, 'weapon_epoch': 0}} for i, x in enumerate([0, 2, 4, 6, 10, 20], 1)]
        completed = [{'leg': i, 'edge_id': name, 'start_tick': start, 'tick': end, 'position': [x, 0]} for i, (name, start, end, x) in enumerate(zip(ids, [1, 2, 6], [1, 5, 6], [0, 10, 20]))]
        data = {'scope': 'full_formal_spawn_Bible_world_Motor', 'route': route, 'seed': 'SYNTHETIC', 'map_index': index,
                'manual_motor_step': False, 'position_or_resource_injection': False, 'manifest': m, 'frames': frames,
                'completed': completed, 'itinerary_count': 3, 'failures': [], 'initial': initial, 'final': {**initial, 'position': [20, 0]},
                'claimed': {f'thorn_forest/map_{index}/bible_backbranch_cache': True}, 'opened': {'bible_backbranch_return': True}}
        if challenge == 'F05':
            data['events'] = [{'kind': 'bible_F05_grounded_departure', 'tick': 2, 'leg': 1, 'method': 'ordinary_walk_off_outside_edge', 'entry_support': 'bible_backbranch__entry'},
                              {'kind': 'bible_F05_actual_descending_side_cast', 'tick': 3, 'leg': 1, 'grounded': False, 'outside_body': True, 'velocity': [0, 100]},
                              {'kind': 'hook_contact_kick', 'tick': 4, 'leg': 1, 'target': 'bible_backbranch__side_fruit'},
                              {'kind': 'shot_fired', 'tick': 5, 'leg': 1}]
        else:
            receipt = {'amount': 0, 'approach_route': 'bible_spiral_approach', 'definition_id': 'spiral_core', 'id': 'forest_spiral_core',
                       'item': 'forest_spiral_core', 'kind': 'item', 'return_route': 'bible_spiral_return', 'story_read': True,
                       'source_id': 'forest_discovery:3:3:' + 'a' * 64 + ':forest_spiral_core'}
            core = {'id': 'forest_spiral_core', 'actual_receipt': receipt, 'item_count_before': 0, 'item_count_after': 1,
                    'projectile_damage_before': 1, 'projectile_damage_after': 2.5, 'claim_via_real_Reader_buttons_and_App_postdamage_queue': True,
                    'direct_claim_or_grant': False}
            data.update(scope='full_formal_spawn_F08_reader_and_other_exit', mode='full', initial_fixture_spawn_override=False,
                        resource_or_health_override=False, direct_claim_or_grant=False, core_evidence=core, claimed={'forest_spiral_core': True})
            data['events'] = [{'kind': 'hook_contact_kick', 'tick': 1, 'leg': 0}, {'kind': 'spiral_actual_reader_bank', 'tick': 2, 'leg': 1},
                              {'kind': 'spiral_actual_queued_item_accepted', 'tick': 5, 'leg': 1, **core}]
            data['pointer_events'] = [{'kind': kind, 'button_text': text, 'rect': [0, 0, 100, 100], 'position': [50, 50]} for text in ('查看发现物', '取用物资并记下线索') for kind in ('mouse_button_press', 'mouse_button_release')]
        return data

    def movie_fixture(self):
        d = self.fixture('F08')
        for row, draw in zip(d['frames'], [2, 4, 6, 8, 16, 18]):
            row.update(presentation_frame=draw, process_frame=100 + draw, observation_phase='physics')
        by = {r['tick']: r for r in d['frames']}
        for row in d['events']:
            frame = by[row['tick']]
            row.update(presentation_frame=frame['presentation_frame'], process_frame=frame['process_frame'], observation_phase='physics')
        d['events'][-1]['observation_phase'] = 'process'
        sample = {'kind': 'hook', 'tick': 2, 'leg': 1}
        aim = {'kind': 'bible_actual_aim_release', 'tick': 2, 'leg': 1, 'sample': sample, 'presentation_frame': 5, 'process_frame': 105, 'observation_phase': 'process'}
        confirm = {'kind': 'actual_input_cancelled', 'reason': 'forest_reader_confirm', 'tick': 4, 'presentation_frame': 13, 'process_frame': 113, 'observation_phase': 'process'}
        d['events'] += [aim, confirm]
        d['events'].sort(key=lambda r: r['presentation_frame'])
        d['aim_samples'] = [sample]
        d['requests'] = [{'kind': 'actual_mouse_button', 'button': 2, 'pressed': False, 'aim_kind': 'hook', 'tick': 2,
                          'presentation_frame': 5, 'process_frame': 105, 'observation_phase': 'process'}]
        for row, draw in zip(d['pointer_events'], [8, 9, 12, 13]):
            row.update(tick=4, presentation_frame=draw, process_frame=100 + draw, observation_phase='process')
        d['modal_frames'] = []
        d['reader_modal_frames'] = [{'tick': 4, 'motion_steps': 4, 'paused': True, 'position': [6, 0], 'actor_epoch': 3, 'stage_epoch': 3,
                                     'presentation_frame': draw, 'process_frame': 100 + draw, 'observation_phase': 'process'} for draw in range(9, 14)]
        for group in ('frames', 'events', 'requests', 'modal_frames', 'reader_modal_frames', 'pointer_events'):
            for row in d[group]: row['engine_physics_frame'] = 1000 + row['presentation_frame']
        d['itinerary'] = av.expected_itinerary(d['manifest'], d['route'])
        return d

    def test_finite_positive_route_shapes(self):
        for challenge, index in [('F05', 1), ('F08', 2)]:
            av.verify_trace(self.fixture(challenge), challenge, index)

    def test_all_report_falseaccept_classes_reject(self):
        mutations = [lambda d: d['frames'][2].update(health=0), lambda d: d['events'].append({'kind': 'committed_damage', 'target': 'player', 'amount': 2}),
                     lambda d: d['frames'][2].update(actor_epoch=999), lambda d: d['frames'][2].update(stage_epoch=999),
                     lambda d: d.update(frames=d['frames'][:1]), lambda d: d.update(claimed={}, opened={}),
                     lambda d: d['final'].update(position=[0, 0]), lambda d: d['completed'][1].update(edge_id='other'),
                     lambda d: d['initial'].update(double_enabled=True)]
        for mutation in mutations:
            d = self.fixture(); mutation(d)
            with self.subTest(mutation=mutation), self.assertRaises(RuntimeError):
                av.verify_trace(d, 'F05', 1)
        d = self.fixture('F08'); d['core_evidence'] = {'garbage': True}
        with self.assertRaises(RuntimeError):
            av.verify_trace(d, 'F08', 2)

    def test_each_core_receipt_effect_and_reader_pointer_is_required(self):
        for mutate in [lambda d: d['core_evidence'].update(item_count_after=2), lambda d: d['core_evidence'].update(projectile_damage_after=1),
                       lambda d: d['core_evidence']['actual_receipt'].update(item='foreign'), lambda d: d.update(pointer_events=[]),
                       lambda d: d.update(claimed={})]:
            d = self.fixture('F08'); mutate(d)
            with self.assertRaises(RuntimeError): av.verify_trace(d, 'F08', 2)

    def test_required_key_events_cannot_degrade_to_first_last_or_constant(self):
        d = self.movie_fixture()
        self.assertEqual(sum(len(r['events']) for r in av.keyframes(d, 20, 'F08')), 5)
        for events in ([], [r for r in d['events'] if r['kind'] != 'spiral_actual_queued_item_accepted']):
            bad = copy.deepcopy(d); bad['events'] = events
            with self.assertRaises(RuntimeError): av.keyframes(bad, 20, 'F08')
        for rows in (d['frames'], d['events']):
            for r in rows: r['presentation_frame'] = 0
        with self.assertRaises(RuntimeError): av.keyframes(d, 20, 'F08')

    def test_paused_process_confirm_is_bounded_and_physics_remains_exact(self):
        d = self.movie_fixture()
        av.verify_movie_timeline(d, 20, 'F08')
        for mutate in [lambda d: d['events'][0].update(presentation_frame=3),
                       lambda d: next(r for r in d['events'] if r['kind'] == 'actual_input_cancelled').update(presentation_frame=16),
                       lambda d: next(r for r in d['events'] if r['kind'] == 'actual_input_cancelled').update(reason='foreign'),
                       lambda d: d['reader_modal_frames'][0].update(motion_steps=999),
                       lambda d: d['pointer_events'][0].update(tick=1),
                       lambda d: d['reader_modal_frames'][-1].update(presentation_frame=16),
                       lambda d: d['requests'][0].pop('observation_phase'), lambda d: d.update(requests=[]),
                       lambda d: d['frames'][1].update(presentation_frame=2), lambda d: d['events'][2].update(observation_phase='unknown')]:
            bad = copy.deepcopy(d); mutate(bad)
            with self.subTest(mutate=mutate), self.assertRaises(RuntimeError): av.verify_movie_timeline(bad, 20, 'F08')

    def test_true_preincrement_engine_identity_uses_detached_validation_view(self):
        d = self.movie_fixture()
        row = d['events'][0]
        row['tick'] -= 1
        before = copy.deepcopy(d)
        result = av.verify_movie_timeline(d, 20, 'F08')
        self.assertEqual(d, before)
        self.assertEqual(result['preincrement_observations'][0]['declared_tick'], 0)
        self.assertEqual(result['preincrement_observations'][0]['observed_tick'], 1)
        for mutate in [lambda d: d['events'][0].update(engine_physics_frame=999999),
                       lambda d: d['events'][0].update(tick=-1),
                       lambda d: d['events'][0].update(presentation_frame=3),
                       lambda d: d['events'][0].update(process_frame=101),
                       lambda d: d['frames'][1].update(engine_physics_frame=d['frames'][0]['engine_physics_frame']),
                       lambda d: d['frames'][0].update(engine_physics_frame=True),
                       lambda d: d['requests'][0].update(observation_phase='physics')]:
            bad = copy.deepcopy(d); mutate(bad)
            with self.subTest(mutate=mutate), self.assertRaises(RuntimeError): av.verify_movie_timeline(bad, 20, 'F08')

    @unittest.skipUnless(shutil.which('ffmpeg') and shutil.which('ffprobe'), 'Requires local media tools, no engine')
    def test_actual_synthetic_short_silent_pcm_rejects(self):
        for duration, reason in [('0.001', 'PCM duration'), ('0.2', 'entirely silent')]:
            with self.subTest(audio_duration=duration), tempfile.TemporaryDirectory() as folder:
                out = Path(folder); path = out / 'SYNTHETIC-NOT-GAME.avi'
                subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-f', 'lavfi', '-i', 'color=c=black:s=1280x720:r=60:d=0.2',
                                '-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo:d=' + duration, '-map', '0:v:0', '-map', '1:a:0',
                                '-c:v', 'mjpeg', '-q:v', '10', '-threads', '1', '-c:a', 'pcm_s16le', str(path)], check=True, timeout=30)
                with self.assertRaisesRegex(RuntimeError, reason): av.media_probe(path, out)

    def test_original_pixel_comparison_refuses_static_frames(self):
        from PIL import Image
        with tempfile.TemporaryDirectory() as folder:
            images = [Path(folder) / f'{i}.png' for i in range(3)]
            for path in images: Image.new('RGB', (1280, 720), 'black').save(path)
            with self.assertRaisesRegex(RuntimeError, 'static'): av.verify_pixel_motion(images)
            Image.new('RGB', (1280, 720), 'white').save(images[1])
            av.verify_pixel_motion(images)


if __name__ == '__main__':
    unittest.main()
