"""Real observed float32 roundoff and invalid shot-ray counterexamples."""
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from run_forest_depth_region import same_shot_direction


class ShotDirectionTests(unittest.TestCase):
    def test_actual_router_then_shoot_normalization(self):
        # Original entry-fourth capture tick1331, native route passed29/2096.
        self.assertTrue(same_shot_direction(
            [-0.70710676908493, 0.70710676908493],
            [-0.707106828689575, 0.707106828689575]))

    def test_distinct_real_rays_reject(self):
        for fired in ([0, -1], [-1, 0], [math.cos(.001), math.sin(.001)]):
            self.assertFalse(same_shot_direction([1, 0], fired))

    def test_invalid_or_nonunit_packets_reject(self):
        for ray in (None, [], [1], [1, 0, 0], [0, 0], [2, 0],
                    [True, 0], ['1', 0], [float('nan'), 0], [float('inf'), 0]):
            self.assertFalse(same_shot_direction(ray, [1, 0]))
            self.assertFalse(same_shot_direction([1, 0], ray))


if __name__ == '__main__':
    unittest.main()
