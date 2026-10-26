"""Counterexamples against an actual recorded trace; pass AUDIO_REELS_TEST_TRACE explicitly."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('capture_audio_reels',ROOT/'tools/capture_audio_reels.py')
capture=importlib.util.module_from_spec(spec);spec.loader.exec_module(capture)

class ActualMovieReceipt(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path=os.environ.get('AUDIO_REELS_TEST_TRACE')
        if not path: raise unittest.SkipTest('Set AUDIO_REELS_TEST_TRACE to a real captured trace.json')
        cls.path=Path(path); cls.trace=json.loads(cls.path.read_text())
        cls.report=json.loads((cls.path.parent/'report.json').read_text())
        cls.reel=cls.trace['reel']
        media=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(cls.path.parent/(cls.reel+'.mp4'))]))
        cls.frames=int(next(s for s in media['streams'] if s['codec_type']=='video')['nb_frames'])
    def reject(self, mutate):
        broken=copy.deepcopy(self.trace);mutate(broken)
        with self.assertRaises(ValueError):capture.validate_trace(broken,self.reel,self.frames)
    def test_actual_complete_movie_receipt(self):
        self.assertEqual(len(capture.validate_trace(self.trace,self.reel,self.frames)),4)
    def test_remove_target_while_complete_audio_file_is_untouched(self):
        self.reject(lambda t:t['segments'][1]['events'].clear())
    def test_remove_playback_while_music_or_other_audio_is_untouched(self):
        self.reject(lambda t:t['segments'][2]['played_delta'].clear())
    def test_repeat_target_is_not_a_successful_comparison(self):
        self.reject(lambda t:t['segments'][1]['events'].append(copy.deepcopy(t['segments'][1]['events'][0])))
    def test_wrong_candidate_path(self):
        self.reject(lambda t:t['segments'][2]['director_events'][0].update(path='res://assets/audio/director_v2/coin_b.wav'))
    def test_missing_profile(self):
        self.reject(lambda t:t['segments'].pop())
    def test_movie_frame_anchor_drift(self):
        self.reject(lambda t:t['movie_clock'].update(frames_drawn_before_quit=self.frames-120))
    def test_unaccepted_formal_result(self):
        self.reject(lambda t:t['segments'][1]['state'].update(wallet=-1,health=-1,build_count=-1))
    def test_fractional_frame_is_rejected_instead_of_truncated(self):
        self.reject(lambda t:t['segments'][1]['director_events'][0].update(movie_frame=246.5))
    def test_nonfinite_frame_is_rejected(self):
        self.reject(lambda t:t['segments'][0]['events'][0].update(movie_frame=float('nan')))
    def test_target_outside_segment(self):
        self.reject(lambda t:t['segments'][0]['events'][0].update(movie_frame=self.frames+1))

class SourceClosure(unittest.TestCase):
    def test_project_audio_configuration_mutation_is_observed(self):
        # Isolated temporary project: never writes the real configuration.
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'tools').mkdir()
            (root/'project.godot').write_text('[audio]\ndriver/mix_rate=44100\n')
            (root/'tools/godot.sh').write_text('#!/bin/sh\nexec godot "$@"\n')
            subprocess.run(['git','init','-q',str(root)],check=True)
            with patch.object(capture,'ROOT',root):
                before=capture.sources()
                (root/'project.godot').write_text('[audio]\ndriver/mix_rate=48000\n')
                after=capture.sources()
            self.assertIn('project.godot',before)
            self.assertIn('tools/godot.sh',before)
            self.assertNotEqual(before,after)

if __name__=='__main__':unittest.main()
