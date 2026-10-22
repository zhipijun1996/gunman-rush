"""Reject body mutations while tolerating actual Godot JSON decimal rounding."""
import importlib.util
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
spec = importlib.util.spec_from_file_location('exploration_motor', ROOT/'tools/run_forest_exploration_motor.py')
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)


class ActualBodySerialization(unittest.TestCase):
    def test_round08_actual_independently_serialized_components(self):
        for position, body in (
            ([258.958435058594,699.923950195312], [246.958435058594,681.923950195312,24.0,36.0]),
            ([150.333312988281,1015.34197998047], [138.333312988281,997.341979980469,24.0,36.0]),
        ):
            with self.subTest(position=position):
                self.assertTrue(reader.actual_player_body(position,body))

    def test_rejects_body_dimensions_without_tolerance(self):
        for width,height in ((24+1e-12,36),(24,36-1e-12),(23,36),(24,35),(True,36)):
            self.assertFalse(reader.actual_player_body([100,100],[88,82,width,height]))

    def test_rejects_material_position_mutation(self):
        for body in ([88+1e-6,82,24,36],[88,82-1e-6,24,36]):
            self.assertFalse(reader.actual_player_body([100,100],body))

    def test_rejects_nonfinite_and_boolean_coordinates(self):
        for value in (float('nan'),float('inf'),-float('inf'),True,False):
            self.assertFalse(reader.actual_player_body([value,100],[88,82,24,36]))
            self.assertFalse(reader.actual_player_body([100,100],[value,82,24,36]))
        self.assertFalse(reader.actual_player_body([100,100],[88,82,24,float('nan')]))


if __name__ == '__main__':
    unittest.main()
