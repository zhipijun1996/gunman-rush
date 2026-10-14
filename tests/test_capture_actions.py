"""Real recording schemas differ for weapon and hook samples; validate both and fail closed."""
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('capture', Path(__file__).resolve().parents[1]/'tools/capture_actions.py')
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
m=importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(m)

class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.media={'streams':[{'codec_type':'video','avg_frame_rate':'60/1'}, {'codec_type':'audio','sample_rate':'48000','channels':2}]}
        self.samples=[{'weapon':s} for s in ['pulse_gun','shadow_shuriken','remote_boomerang','triple_machine_gun','sustained_laser','fan_shuriken','magnetic_mine','collapse_singularity']]+[{'demo':'hook_hit'},{'demo':'hook_miss'}]
    def test_actual_mixed_schema_is_complete(self):
        self.assertEqual(len(m.validate_capture(self.media,{'trace':self.samples*200})),10)
    def test_missing_demo_fails(self):
        with self.assertRaises(RuntimeError): m.validate_capture(self.media,{'trace':self.samples[:-1]*250})
    def test_substitute_demo_does_not_count_as_coverage(self):
        with self.assertRaises(RuntimeError): m.validate_capture(self.media,{'trace':(self.samples[:-1]+[{'demo':'unknown'}])*200})
    def test_short_recording_fails(self):
        with self.assertRaises(RuntimeError): m.validate_capture(self.media,{'trace':self.samples})
    def test_wrong_audio_fails(self):
        self.media['streams'][1]['channels']=1
        with self.assertRaises(RuntimeError): m.validate_capture(self.media,{'trace':self.samples*200})

if __name__=='__main__': unittest.main()
