"""Check the region-only spatial proposal before room subdivision."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/world'))
from region_atlas import validate


class RegionAtlasTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads((ROOT / 'config/world/region_atlas.json').read_text())

    def test_world_is_connected_without_overlap_and_both_hubs_have_five_neighbors(self):
        result = validate(self.data)
        self.assertEqual(result['regions'], 16)
        self.assertEqual(result['interfaces'], 30)
        self.assertEqual(result['overlaps'], 0)
        self.assertEqual(result['city_neighbors'], ['A', 'E', 'K', 'N', 'P'])
        self.assertEqual(result['mine_neighbors'], ['E', 'G', 'P', 'R', 'S'])
        self.assertGreater(result['area_ratio_city_to_plains'], 2)
        self.assertNotIn('rooms', self.data)

    def test_interface_cannot_float_inside_one_region(self):
        self.data['interfaces'][0]['point'][0] += 64
        with self.assertRaisesRegex(AssertionError, 'A01'):
            validate(self.data)

    def test_touching_at_a_corner_is_not_an_interface(self):
        # A real portal needs boundary clearance on both sides of its center.
        edge = self.data['interfaces'][0]
        for y in (480, 700):
            with self.subTest(y=y):
                edge['point'] = [620 * 32, y * 32]
                with self.assertRaisesRegex(AssertionError, 'Corner-only port A01'):
                    validate(self.data)

    def test_overlapping_regions_are_rejected(self):
        target = next(r for r in self.data['regions'] if r['id'] == 'I')
        target['outline'] = [[x, y + 64] for x, y in target['outline']]
        target['label'][1] += 64
        with self.assertRaisesRegex(AssertionError, 'Overlap'):
            validate(self.data)

    def test_stage_route_cannot_jump_between_non_adjacent_regions(self):
        self.data['routes'][0]['regions'] = ['P', 'I']
        with self.assertRaisesRegex(AssertionError, 'early'):
            validate(self.data)


if __name__ == '__main__':
    unittest.main()
