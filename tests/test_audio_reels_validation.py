"""Numerical counterexamples: silent tails must not become giant correlations."""
import sys
from pathlib import Path
import unittest
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from audio_reels_validation import stable_match,joint_fit

class StableAudioMatch(unittest.TestCase):
 def test_exact_short_cue_after_long_silent_tail(self):
  rng=np.random.default_rng(191);ref=rng.normal(size=700);signal=np.zeros(18000);signal[317:1017]=ref*.07
  correlation,index=stable_match(signal,ref)
  self.assertEqual(index,317);self.assertAlmostEqual(correlation,1.,places=12)
 def test_silence_cannot_claim_a_match(self):
  with self.assertRaisesRegex(ValueError,'energy'):stable_match(np.zeros(10000),np.ones(100))
 def test_empty_reference_is_rejected(self):
  with self.assertRaises(ValueError):stable_match(np.ones(1000),np.zeros(20))
 def test_full_window_recheck_obeys_cauchy_bound(self):
  rng=np.random.default_rng(192);ref=rng.normal(size=300);signal=rng.normal(size=20000)*1e-10;signal[100:400]+=ref*.1
  correlation,index=stable_match(signal,ref)
  self.assertEqual(index,100);self.assertLessEqual(correlation,1.)

class JointLayerPresence(unittest.TestCase):
 def setUp(self):
  rng=np.random.default_rng(193);self.design=np.linalg.qr(rng.normal(size=(1000,2)))[0]
 def test_two_meaningful_components_pass(self):
  result=joint_fit(self.design,self.design@np.array([.4,.3]))
  self.assertAlmostEqual(result['joint_r2'],1.);self.assertGreater(min(result['r2_gain_over_single_components']),.01)
 def test_pure_blast_is_not_a_launch(self):
  with self.assertRaises(ValueError):joint_fit(self.design,self.design[:,1])
 def test_tiny_positive_launch_is_not_evidence(self):
  with self.assertRaises(ValueError):joint_fit(self.design,self.design@np.array([1e-9,.3]))
 def test_missing_blast_fails(self):
  with self.assertRaises(ValueError):joint_fit(self.design,self.design[:,0])

if __name__=='__main__':unittest.main()
