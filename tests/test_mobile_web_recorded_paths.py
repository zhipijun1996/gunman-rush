"""Finite source/PCK layout regressions; no Godot or historical package acceptance."""
import ast
import hashlib
import pathlib
import subprocess
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
sys.path.insert(0, str(ROOT / 'tools/mobile_web_perf'))
import build_probe as current
import build_frame_profile as frame
import build_formal_audio_ab as formal
import run_minimal as minimal


def git_source(commit, path):
    return subprocess.check_output(['git', 'show', commit + ':' + path], cwd=ROOT)


def literal_assignment(source, name):
    for node in ast.parse(source).body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == name for t in node.targets):
            return ast.literal_eval(node.value)
    raise AssertionError('Missing frozen assignment: ' + name)


class RecordedPaths(unittest.TestCase):
    def test_fixed_measure_protocol_and_all_real_git_sources(self):
        original = git_source('2ce4ffa6', 'tools/mobile_web_perf/build_probe.py').decode()
        self.assertEqual(formal.MEASURE, literal_assignment(original, 'MEASURE'))
        self.assertEqual(formal.MEASURE_COMMIT, formal.COMMIT)
        self.assertEqual(len(formal.MEASURE), 16)
        for path in formal.MEASURE:
            with self.subTest(path=path):
                self.assertTrue(formal.git_source(path))
        audio = formal.git_source('scripts/audio/game_audio.gd')
        self.assertEqual(hashlib.sha256(audio).hexdigest(), minimal.GAME_AUDIO_SHA)
        self.assertTrue(formal.git_source('scenes/demo/demo.tscn'))

    def test_fixed_wrappers_and_treatments_still_byte_exact(self):
        # Test-only original consumer, not a second production instrumenter.
        previous = types.ModuleType('recorded_formal_before_layout')
        previous.__file__ = str(ROOT / 'tools/mobile_web_perf/build_formal_audio_ab.py')
        exec(compile(git_source('2ce4ffa6', 'tools/mobile_web_perf/build_formal_audio_ab.py'), previous.__file__, 'exec'), previous.__dict__)
        previous.MEASURE = dict(formal.MEASURE)
        for path, methods in formal.MEASURE.items():
            with self.subTest(path=path):
                raw = formal.git_source(path)
                actual, expected = formal.Edits(path, raw), previous.Edits(path, raw)
                formal.treatments(actual)
                formal.observe(actual, methods)
                previous.treatments(expected)
                previous.observe(expected, methods)
                self.assertTrue(actual.verify_reverse())
                self.assertEqual(actual.text, expected.text)
                self.assertEqual(actual.steps, expected.steps)

    def test_fixed_pack_identity_rejects_other_bytes_before_pack_load(self):
        with tempfile.TemporaryDirectory() as temp:
            wrong = pathlib.Path(temp) / 'wrong.pck'
            wrong.write_bytes(b'not the fixed main1b pack')
            with patch.object(minimal, 'Pack') as load:
                with self.assertRaisesRegex(AssertionError, 'Wrong baseline PCK'):
                    minimal.build_bundle(pathlib.Path(temp) / 'minimal', wrong)
                load.assert_not_called()
            with patch.object(formal, 'Pack') as load:
                with self.assertRaisesRegex(ValueError, 'fingerprint mismatch'):
                    formal.build(types.SimpleNamespace(baseline_pack=wrong), pathlib.Path(temp), {})
                load.assert_not_called()

    def test_minimal_replacement_addresses_original_scene(self):
        observed = {}
        class StopBeforePackWrite(Exception):
            pass
        def observe(pack, replacements, skip, target):
            observed.update(replacements)
            raise StopBeforePackWrite
        with tempfile.TemporaryDirectory() as temp:
            # Only observe original replacement assembly. No synthetic PCK is accepted/written.
            with patch.object(minimal, 'digest', return_value=minimal.PACK_SHA), patch.object(minimal, 'Pack'), patch.object(minimal, 'write_pack', side_effect=observe):
                with self.assertRaises(StopBeforePackWrite):
                    minimal.build_bundle(pathlib.Path(temp) / 'output', pathlib.Path(temp) / 'not-read.pck')
        self.assertEqual(observed['scenes/demo/demo.tscn'], minimal.SCENE)
        self.assertIn('scenes/demo/demo.tscn.remap', observed)
        self.assertNotIn('game/application/demo.tscn', observed)
        self.assertEqual(minimal.PACK_SHA, formal.PACK_SHA)

    def test_frame_recorded_and_current_complete_layouts(self):
        measured = {**frame.MEASURE, **frame.ACTION_MEASURE}
        old_entries = {path + '.remap' for path in measured}
        self.assertEqual(frame.measurement_paths('2ce4ffa6', old_entries, measured), {p: p for p in measured})
        new_entries = {frame.CURRENT_PATHS[path] + '.remap' for path in measured}
        self.assertEqual(frame.measurement_paths('HEAD', new_entries, measured), {p: frame.CURRENT_PATHS[p] for p in measured})
        previous = git_source('2ce4ffa6', 'tools/mobile_web_perf/build_frame_profile.py').decode()
        self.assertEqual(frame.MEASURE, literal_assignment(previous, 'MEASURE'))
        self.assertEqual(frame.ACTION_MEASURE, literal_assignment(previous, 'ACTION_MEASURE'))

    def test_frame_main_uses_selected_pack_keys_with_real_commit_sources(self):
        class StopBeforePackWrite(Exception):
            pass
        cases = []
        for detail in (False, True):
            measured = {**frame.MEASURE, **(frame.ACTION_MEASURE if detail else {})}
            cases.extend([(commit, detail, {p: frame.CURRENT_PATHS[p] if commit == 'HEAD' else p for p in measured})
                          for commit in ('2ce4ffa6', 'HEAD')])
        for commit, detail, paths in cases:
            with self.subTest(commit=commit, action_detail=detail), tempfile.TemporaryDirectory() as temp:
                folder = pathlib.Path(temp)
                payload = b'fixture layout only; not a real exported package'
                (folder / 'input.pck').write_bytes(payload)
                import json
                (folder / 'build-info.json').write_text(json.dumps({'source_commit': commit, 'pack': 'input.pck', 'build_id': frame.sha(payload)[:12]}))
                observed = {}
                def observe(pack, replacements, skip, target):
                    observed.update(replacements=replacements, skip=skip)
                    raise StopBeforePackWrite
                entries = {path + '.remap' for path in paths.values()}
                args = ['build_frame_profile.py', '--bundle', str(folder), '--output', str(folder / 'output')]
                if detail:
                    args.append('--action-detail')
                with patch.object(sys, 'argv', args), patch.object(frame, 'Pack', return_value=types.SimpleNamespace(entries=entries)), patch.object(frame, 'write_pack', side_effect=observe):
                    with self.assertRaises(StopBeforePackWrite):
                        frame.main()
                self.assertEqual(set(observed['replacements']), set(paths.values()) | {'fps04_profile.gd'})
                self.assertEqual(observed['skip'], entries)
                app = paths['scripts/demo/demo_app.gd']
                self.assertIn(b'add_child.call_deferred(load("res://fps04_profile.gd").new())', observed['replacements'][app])
                if detail:
                    chest = paths['scripts/art/chest_art_library.gd']
                    self.assertIn(b'static func _fps04_static_record', observed['replacements'][chest])
                self.assertFalse((folder / 'output/diagnostic.pck').exists())

    def test_frame_rejects_wrong_declared_source_and_missing_pack_entries(self):
        measured = frame.MEASURE
        old_entries = {p + '.remap' for p in measured}
        new_entries = {frame.CURRENT_PATHS[p] + '.remap' for p in measured}
        for commit, entries in [('HEAD', old_entries), ('2ce4ffa6', new_entries), ('2ce4ffa6', set()), ('HEAD', new_entries - {next(iter(new_entries))})]:
            with self.subTest(commit=commit, entries=len(entries)):
                with self.assertRaisesRegex(ValueError, 'Missing or ambiguous'):
                    frame.measurement_paths(commit, entries, measured)

    def test_frame_rejects_mixed_and_ambiguous_layouts(self):
        measured = frame.MEASURE
        source_tree = '\n'.join([*measured, *(frame.CURRENT_PATHS[p] for p in measured)])
        complete_old = {p + '.remap' for p in measured}
        first = next(iter(measured))
        mixed = complete_old - {first + '.remap'} | {frame.CURRENT_PATHS[first] + '.remap'}
        with patch.object(frame.subprocess, 'check_output', return_value=source_tree):
            with self.assertRaisesRegex(ValueError, 'Mixed'):
                frame.measurement_paths('synthetic-mixed-tree', mixed, measured)
            with self.assertRaisesRegex(ValueError, 'ambiguous'):
                frame.measurement_paths('synthetic-ambiguous-tree', complete_old | {frame.CURRENT_PATHS[first] + '.remap'}, measured)

    def test_candidate_override_does_not_alias_current_source_into_old_pack(self):
        old = 'scripts/art/chest_art_library.gd'
        new = frame.CURRENT_PATHS[old]
        self.assertEqual(frame.candidate_sources([old], {old: old}), [old])
        self.assertEqual(frame.candidate_sources([new], {old: new}), [new])
        with self.assertRaisesRegex(ValueError, 'selected source/PCK layout'):
            frame.candidate_sources([new], {old: old})

    def test_current_producer_rejects_old_partial_or_mixed_measured_paths(self):
        complete = {p + '.remap' for p in current.MEASURE}
        current.require_current_measurement_paths(types.SimpleNamespace(entries=complete))
        historical = {p + '.remap' for p in formal.MEASURE}
        first = next(iter(complete))
        for entries in (historical, set(), complete - {first}, complete - {first} | {next(iter(historical))}):
            with self.assertRaisesRegex(ValueError, 'complete current measurement layout'):
                current.require_current_measurement_paths(types.SimpleNamespace(entries=entries))


if __name__ == '__main__':
    unittest.main()
